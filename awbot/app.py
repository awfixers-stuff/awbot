import asyncio
import signal
from types import FrameType

import discord
import sentry_sdk
from loguru import logger

from awbot.bot import awbot
from awbot.help import awbotHelp
from awbot.utils.config import CONFIG
from awbot.utils.env import get_current_env

async def get_prefix(bot: awbot, message: discord.Message) -> list[str]:
    prefix: str | None = None
    if message.guild:
        try:
            from awbot.database.controllers import DatabaseController
            prefix = await DatabaseController().guild_config.get_guild_prefix(message.guild.id)
        except Exception as e:
            logger.error(f"Error getting guild prefix: {e}")
    return [prefix or CONFIG.DEFAULT_PREFIX]

class awbotApp:
    def __init__(self):
        self.bot = None

    def run(self) -> None:
        asyncio.run(self.start())

    def setup_sentry(self) -> None:
        if not CONFIG.SENTRY_DSN:
            logger.warning("No Sentry DSN configured, skipping Sentry setup")
            return
        logger.info("Setting up Sentry...")
        try:
            sentry_sdk.init(
                dsn=CONFIG.SENTRY_DSN,
                release=CONFIG.BOT_VERSION,
                environment=get_current_env(),
                enable_tracing=True,
                attach_stacktrace=True,
                send_default_pii=False,
                traces_sample_rate=1.0,
                profiles_sample_rate=1.0,
                _experiments={
                    "enable_logs": True,
                },
            )
            sentry_sdk.set_tag("discord_library_version", discord.__version__)
            logger.info(f"Sentry initialized: {sentry_sdk.is_initialized()}")
        except Exception as e:
            logger.error(f"Failed to initialize Sentry: {e}")

    def setup_signals(self) -> None:
        signal.signal(signal.SIGTERM, self.handle_sigterm)
        signal.signal(signal.SIGINT, self.handle_sigterm)

    def handle_sigterm(self, signum: int, frame: FrameType | None) -> None:
        logger.info(f"Received signal {signum}")
        if sentry_sdk.is_initialized():
            with sentry_sdk.push_scope() as scope:
                scope.set_tag("signal.number", signum)
                scope.set_tag("lifecycle.event", "termination_signal")
                sentry_sdk.add_breadcrumb(
                    category="lifecycle",
                    message=f"Received termination signal {signum}",
                    level="info",
                )
        raise KeyboardInterrupt

    def validate_config(self) -> bool:
        if not CONFIG.BOT_TOKEN:
            logger.critical("No bot token provided. Set DEV_BOT_TOKEN or PROD_BOT_TOKEN in your .env file.")
            return False
        return True

    async def start(self) -> None:
        self.setup_sentry()
        self.setup_signals()
        if not self.validate_config():
            return
        owner_ids = {CONFIG.BOT_OWNER_ID}
        if CONFIG.ALLOW_SYSADMINS_EVAL:
            logger.warning(
                "⚠️ Eval is enabled for sysadmins, this is potentially dangerous; see settings.yml.example for more info.",
            )
            owner_ids.update(CONFIG.SYSADMIN_IDS)
        else:
            logger.warning("🔒️ Eval is disabled for sysadmins; see settings.yml.example for more info.")
        self.bot = awbot(
            command_prefix=get_prefix,
            strip_after_prefix=True,
            case_insensitive=True,
            intents=discord.Intents.all(),
            owner_ids=owner_ids,
            allowed_mentions=discord.AllowedMentions(everyone=False),
            help_command=awbotHelp(),
            activity=None,
            status=discord.Status.online,
        )
        try:
            await self.bot.start(CONFIG.BOT_TOKEN, reconnect=True)
        except KeyboardInterrupt:
            logger.info("Shutdown requested (KeyboardInterrupt)")
        except Exception as e:
            logger.critical(f"Bot failed to start: {e}")
            await self.shutdown()
        finally:
            await self.shutdown()

    async def shutdown(self) -> None:
        if self.bot and not self.bot.is_closed():
            await self.bot.shutdown()
        if sentry_sdk.is_initialized():
            sentry_sdk.flush()
            await asyncio.sleep(0.1)
        logger.info("Shutdown complete")