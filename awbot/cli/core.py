import importlib
import os
import subprocess
import sys
from collections.abc import Callable
from functools import update_wrapper
from typing import Any, TypeVar

import click
from click import Command, Context, Group
from loguru import logger

from awbot import __version__
from awbot.cli.ui import command_header, command_result, error, info, warning
from awbot.utils.env import (
    configure_environment,
    get_current_env,
    get_database_url,
)
from awbot.utils.logger import setup_logging

T = TypeVar("T")
CommandFunction = Callable[..., int]

GROUP_HELP_SUFFIX = ""

NO_DB_COMMANDS = {"dev", "docs", "docker"}

def run_command(cmd: list[str], **kwargs: Any) -> int:
    try:
        subprocess.run(cmd, check=True, **kwargs)
    except subprocess.CalledProcessError as e:
        return e.returncode
    else:
        return 0

class GlobalOptionGroup(click.Group):
    def parse_args(self, ctx: Context, args: list[str]) -> list[str]:
        is_dev = True
        remaining_args: list[str] = []
        args_iterator = iter(args)
        for arg in args_iterator:
            if arg == "--dev":
                is_dev = True
            elif arg == "--prod":
                is_dev = False
            else:
                remaining_args.append(arg)
        ctx.meta["is_dev"] = is_dev
        return super().parse_args(ctx, remaining_args)

@click.group(cls=GlobalOptionGroup)
@click.version_option(version=__version__, prog_name="awbot")
@click.pass_context
def cli(ctx: Context) -> None:
    ctx.ensure_object(dict)
    ctx.meta.setdefault("is_dev", True)
    is_dev = ctx.meta["is_dev"]
    configure_environment(dev_mode=is_dev)
    invoked_command = ctx.invoked_subcommand
    if invoked_command is not None and invoked_command not in NO_DB_COMMANDS:
        logger.trace(f"Command '{invoked_command}' may require database access. Setting DATABASE_URL.")
        try:
            db_url = get_database_url()
            os.environ["DATABASE_URL"] = db_url
            logger.trace("Set DATABASE_URL environment variable for Prisma.")
        except Exception as e:
            logger.critical(f"Command '{invoked_command}' requires a database, but failed to configure URL: {e}")
            logger.critical("Ensure DEV_DATABASE_URL or PROD_DATABASE_URL is set in your .env file or environment.")
            sys.exit(1)
    elif invoked_command:
        logger.trace(f"Command '{invoked_command}' does not require database access. Skipping DATABASE_URL setup.")

def command_registration_decorator(
    target_group: Group,
    *args: Any,
    **kwargs: Any,
) -> Callable[[CommandFunction], Command]:
    def decorator(func: CommandFunction) -> Command:
        @click.pass_context
        def wrapper(ctx: Context, **kwargs: Any):
            group_name = (ctx.parent.command.name or "cli") if ctx.parent and ctx.parent.command else "cli"
            cmd_name = (ctx.command.name or "unknown") if ctx.command else "unknown"
            command_header(group_name, cmd_name)
            info(f"Running in {get_current_env()} mode")
            try:
                result = func(**kwargs)
                success = result == 0
                command_result(success)
                return result
            except Exception as e:
                error(f"Command failed: {e!s}")
                logger.exception("An error occurred during command execution.")
                command_result(False)
                return 1
        wrapper = update_wrapper(wrapper, func)
        return target_group.command(*args, **kwargs)(wrapper)
    return decorator

def create_group(name: str, help_text: str) -> Group:
    @cli.group(name=name, help=help_text)
    def group_func() -> None:
        pass
    return group_func

def register_commands() -> None:
    modules = ["database", "dev", "docs", "docker", "test"]
    for module_name in modules:
        try:
            importlib.import_module(f"awbot.cli.{module_name}")
        except ImportError as e:
            warning(f"Failed to load command module {module_name}: {e}")

def main() -> int:
    setup_logging()
    register_commands()
    return cli() or 0

@command_registration_decorator(cli, name="start")
def start() -> int:
    from awbot.main import run
    result = run()
    return 0 if result is None else result

@command_registration_decorator(cli, name="version")
def show_version() -> int:
    info(f"awbot version: {__version__}")
    return 0

register_commands()