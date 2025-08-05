import os
from collections.abc import Callable
from typing import TypeVar

from loguru import logger

from awbot.cli.core import command_registration_decorator, create_group, run_command
from awbot.utils.env import get_database_url

T = TypeVar("T")
CommandFunction = Callable[[], int]

def _run_prisma_command(args: list[str], env: dict[str, str]) -> int:
    logger.info(f"Using database URL: {env['DATABASE_URL']}")
    env_vars = os.environ | env
    try:
        logger.info(f"Running: prisma {' '.join(args)}")
        return run_command(["prisma", *args], env=env_vars)
    except Exception as e:
        logger.error(f"Error running prisma command: {e}")
        return 1

db_group = create_group("db", "Database management commands")

@command_registration_decorator(db_group, name="generate")
def generate() -> int:
    env = {"DATABASE_URL": get_database_url()}
    return _run_prisma_command(["generate"], env=env)

@command_registration_decorator(db_group, name="push")
def push() -> int:
    env = {"DATABASE_URL": get_database_url()}
    return _run_prisma_command(["db", "push"], env=env)

@command_registration_decorator(db_group, name="pull")
def pull() -> int:
    env = {"DATABASE_URL": get_database_url()}
    return _run_prisma_command(["db", "pull"], env=env)

@command_registration_decorator(db_group, name="migrate")
def migrate() -> int:
    env = {"DATABASE_URL": get_database_url()}
    return _run_prisma_command(["migrate", "dev"], env=env)

@command_registration_decorator(db_group, name="reset")
def reset() -> int:
    env = {"DATABASE_URL": get_database_url()}
    return _run_prisma_command(["migrate", "reset"], env=env)