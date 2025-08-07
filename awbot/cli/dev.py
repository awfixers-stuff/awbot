from awbot.cli.core import (
    command_registration_decorator,
    create_group,
    run_command,
)

dev_group = create_group("dev", "Development tools")

@command_registration_decorator(dev_group, name="lint")
def lint() -> int:
    return run_command(["ruff", "check", "."])

@command_registration_decorator(dev_group, name="lint-fix")
def lint_fix() -> int:
    return run_command(["ruff", "check", "--fix", "."])

@command_registration_decorator(dev_group, name="format")
def format_code() -> int:
    return run_command(["ruff", "format", "."])

@command_registration_decorator(dev_group, name="type-check")
def type_check() -> int:
    return run_command(["pyright"])

@command_registration_decorator(dev_group, name="pre-commit")
def check() -> int:
    return run_command(["pre-commit", "run", "--all-files"])