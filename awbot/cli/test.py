from pathlib import Path

import click
from loguru import logger

from awbot.cli.core import command_registration_decorator, create_group, run_command

test_group = create_group(
    "test",
    "Test commands for running various types of tests and generating reports.",
)

@command_registration_decorator(test_group, name="run")
def test() -> int:
    return run_command(["pytest", "--cov=awbot", "--cov-report=term-missing", "--randomly-seed=last"])

@command_registration_decorator(test_group, name="quick")
def test_quick() -> int:
    return run_command(["pytest", "--no-cov", "--randomly-seed=last"])

@command_registration_decorator(test_group, name="plain")
def test_plain() -> int:
    return run_command(["pytest", "-p", "no:sugar", "--cov=awbot", "--cov-report=term-missing", "--randomly-seed=last"])

@command_registration_decorator(test_group, name="parallel")
def test_parallel() -> int:
    return run_command(["pytest", "--cov=awbot", "--cov-report=term-missing", "-n", "auto", "--randomly-seed=last"])

@command_registration_decorator(test_group, name="html")
def test_html() -> int:
    return run_command(
        [
            "pytest",
            "--cov=awbot",
            "--cov-report=html",
            "--html=reports/test_report.html",
            "--self-contained-html",
            "--randomly-seed=last",
        ],
    )

@command_registration_decorator(test_group, name="benchmark")
def test_benchmark() -> int:
    return run_command(["pytest", "--benchmark-only", "--benchmark-sort=mean"])

@command_registration_decorator(test_group, name="coverage")
@click.option(
    "--format",
    "report_format",
    type=click.Choice(["term", "html", "xml", "json"], case_sensitive=False),
    default="term",
    help="Coverage report format",
)
@click.option(
    "--fail-under",
    type=click.IntRange(0, 100),
    help="Fail if coverage is below this percentage",
)
@click.option(
    "--open-browser",
    is_flag=True,
    help="Open HTML report in browser (only with --format=html)",
)
@click.option(
    "--quick",
    is_flag=True,
    help="Quick coverage check without generating reports",
)
@click.option(
    "--clean",
    is_flag=True,
    help="Clean coverage files before running",
)
@click.option(
    "--specific",
    type=str,
    help="Run coverage for specific path (e.g., awbot/utils)",
)
@click.option(
    "--plain",
    is_flag=True,
    help="Use plain output (disable pytest-sugar)",
)
@click.option(
    "--xml-file",
    type=str,
    help="Custom XML filename (only with --format=xml, e.g., coverage-unit.xml)",
)
def coverage(
    report_format: str,
    fail_under: int | None,
    open_browser: bool,
    quick: bool,
    clean: bool,
    specific: str | None,
    plain: bool,
    xml_file: str | None,
) -> int:
    if clean:
        _clean_coverage_files()
    cmd = _build_coverage_command(specific, quick, report_format, fail_under, plain, xml_file)
    result = run_command(cmd)
    if result == 0 and open_browser and report_format == "html":
        _open_html_report()
    return result

@command_registration_decorator(test_group, name="coverage-clean")
def coverage_clean() -> int:
    return _clean_coverage_files()

@command_registration_decorator(test_group, name="coverage-open")
def coverage_open() -> int:
    return _open_html_report()

def _build_coverage_command(
    specific: str | None,
    quick: bool,
    report_format: str,
    fail_under: int | None,
    plain: bool = False,
    xml_file: str | None = None,
) -> list[str]:
    cmd = ["pytest"]
    if plain:
        logger.info("Using plain output (pytest-sugar disabled)...")
        cmd.extend(["-p", "no:sugar"])
    if specific:
        logger.info(f"Running coverage for specific path: {specific}")
        cmd.append(f"--cov={specific}")
    else:
        cmd.append("--cov=awbot")
    if quick:
        logger.info("Quick coverage check (no reports)...")
        cmd.append("--cov-report=")
        cmd.extend(["--randomly-seed=last"])
        return cmd
    _add_report_format(cmd, report_format, xml_file)
    if fail_under is not None:
        logger.info(f"Running with {fail_under}% coverage threshold...")
        cmd.extend(["--cov-fail-under", str(fail_under)])
    cmd.extend(["--randomly-seed=last"])
    return cmd

def _add_report_format(cmd: list[str], report_format: str, xml_file: str | None = None) -> None:
    if report_format == "html":
        cmd.append("--cov-report=html")
        logger.info("Generating HTML coverage report...")
    elif report_format == "json":
        cmd.append("--cov-report=json")
        logger.info("Generating JSON coverage report...")
    elif report_format == "term":
        cmd.append("--cov-report=term-missing")
    elif report_format == "xml":
        if xml_file:
            cmd.append(f"--cov-report=xml:{xml_file}")
            logger.info(f"Generating XML coverage report: {xml_file}")
        else:
            cmd.append("--cov-report=xml")
            logger.info("Generating XML coverage report...")

def _clean_coverage_files() -> int:
    import shutil
    coverage_files = [
        ".coverage",
        ".coverage.*",
        "htmlcov/",
        "coverage.xml",
        "coverage.json",
    ]
    logger.info("🧹 Cleaning coverage files...")
    for pattern in coverage_files:
        if "*" in pattern:
            for file_path in Path().glob(pattern):
                Path(file_path).unlink(missing_ok=True)
                logger.debug(f"Removed: {file_path}")
        else:
            path = Path(pattern)
            if path.is_file():
                path.unlink()
                logger.debug(f"Removed file: {path}")
            elif path.is_dir():
                shutil.rmtree(path, ignore_errors=True)
                logger.debug(f"Removed directory: {path}")
    logger.info("Coverage cleanup completed")
    return 0

def _open_html_report() -> int:
    import webbrowser
    html_report_path = Path("htmlcov/index.html")
    if not html_report_path.exists():
        logger.error("HTML coverage report not found. Run coverage with --format=html first.")
        return 1
    try:
        webbrowser.open(f"file://{html_report_path.resolve()}")
        logger.info("Opening HTML coverage report in browser...")
    except Exception as e:
        logger.error(f"Failed to open HTML report: {e}")
        return 1
    else:
        return 0