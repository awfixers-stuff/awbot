import pathlib

from loguru import logger

from awbot.cli.core import (
    command_registration_decorator,
    create_group,
    run_command,
)

docs_group = create_group("docs", "Documentation related commands")

def find_mkdocs_config() -> str:
    current_dir = pathlib.Path.cwd()
    if (current_dir / "mkdocs.yml").exists():
        return "mkdocs.yml"
    if (current_dir / "docs" / "mkdocs.yml").exists():
        return "docs/mkdocs.yml"
    logger.error("Can't find mkdocs.yml file. Please run from the project root or docs directory.")
    return ""

@command_registration_decorator(docs_group, name="serve")
def docs_serve() -> int:
    if mkdocs_path := find_mkdocs_config():
        return run_command(["mkdocs", "serve", "--dirty", "-f", mkdocs_path])
    return 1

@command_registration_decorator(docs_group, name="build")
def docs_build() -> int:
    if mkdocs_path := find_mkdocs_config():
        return run_command(["mkdocs", "build", "-f", mkdocs_path])
    return 1