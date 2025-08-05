import asyncio
import discord
import sentry_sdk
from loguru import logger

class DatabaseConnectionError(Exception):
    pass

class awbot(discord.AutoShardedBot):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.db = None
        self.extensions_loaded = False
        self.cogs_loaded = False
        self.tasks = []
        self._monitoring = False
        self._setup_complete = asyncio.Event()
        self._shutdown_complete = asyncio.Event()
        self._setup_task = None
        self._monitor_task = None
        self._transaction_stack = []

    async def setup(self):
        await self._setup_database()
        await self._load_extensions()
        self._start_monitoring()
        self._setup_complete.set()

    async def _setup_database(self):
        try:
            from awbot.database.client import DatabaseClient
            self.db = await DatabaseClient().connect()
        except Exception as e:
            logger.critical(f"Database connection failed: {e}")
            raise DatabaseConnectionError from e

    async def _load_extensions(self):
        if self.extensions_loaded:
            return
        from awbot.extensions import EXTENSIONS
        for ext in EXTENSIONS:
            try:
                await self.load_extension(ext)
            except Exception as e:
                logger.error(f"Failed to load extension {ext}: {e}")
        self.extensions_loaded = True

    def _start_monitoring(self):
        if not self._monitoring:
            self._monitor_task = asyncio.create_task(self._monitor_tasks_loop())
            self._monitoring = True

    def _validate_db_connection(self):
        if not self.db:
            raise DatabaseConnectionError("Database not connected")

    def _setup_callback(self, callback):
        self._setup_task = asyncio.create_task(callback())

    async def setup_hook(self):
        await self.setup()

    async def _post_ready_startup(self):
        if not self.cogs_loaded:
            await self._load_cogs()
            self.cogs_loaded = True

    async def on_ready(self):
        await self._post_ready_startup()
        logger.info(f"Bot ready: {self.user}")

    async def on_disconnect(self):
        logger.warning("Bot disconnected from Discord")

    def start_interaction_transaction(self):
        self._transaction_stack.append("interaction")

    def start_command_transaction(self):
        self._transaction_stack.append("command")

    def finish_transaction(self):
        if self._transaction_stack:
            self._transaction_stack.pop()

    async def _wait_for_setup(self):
        await self._setup_complete.wait()

    async def _monitor_tasks_loop(self):
        while not self._shutdown_complete.is_set():
            await asyncio.sleep(1)
            self._categorize_tasks()
            await self._process_finished_tasks()

    def _categorize_tasks(self):
        pass

    async def _process_finished_tasks(self):
        pass

    async def shutdown(self):
        self._shutdown_complete.set()
        if self._monitor_task:
            self._monitor_task.cancel()
            try:
                await self._monitor_task
            except asyncio.CancelledError:
                pass
        await self._cleanup_tasks()
        await self._close_connections()

    async def _handle_setup_task(self):
        if self._setup_task:
            await self._setup_task

    async def _cleanup_tasks(self):
        for task in self.tasks:
            if not task.done():
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass
        self.tasks.clear()

    async def _stop_task_loops(self):
        if self._monitor_task:
            self._monitor_task.cancel()
            try:
                await self._monitor_task
            except asyncio.CancelledError:
                pass

    async def _cancel_tasks(self):
        for task in self.tasks:
            if not task.done():
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass

    async def _close_connections(self):
        if self.db:
            await self.db.disconnect()
            self.db = None

    async def _load_cogs(self):
        from awbot.cog_loader import load_cogs
        await load_cogs(self)

    async def _log_startup_banner(self):
        logger.info("awbot started")

    async def _setup_hot_reload(self):
        from awbot.utils.hot_reload import setup_hot_reload
        await setup_hot_reload(self)