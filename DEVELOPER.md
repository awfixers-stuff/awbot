# Developer Guide: awbot

Welcome to the awbot developer documentation!

This area provides in-depth information for developers working on awbot, beyond the initial setup and contribution workflow.

## Getting Started & Contributing

For information on setting up your environment, the development workflow (branching, PRs), and basic quality checks, please refer to the main contribution guide:

* [**Contributing Guide**](./.github/CONTRIBUTING.md)

## Developer Topics

Explore the following pages for more detailed information on specific development aspects:

* **[Local Development](./docs/content/dev/local_development.md)**
  * Running the bot locally.
  * Understanding the hot reloading mechanism.
* **[awbot CLI Usage](./docs/content/dev/cli/index.md)**
  * Understanding development vs. production modes (`--dev`, `--prod`).
  * Overview of command groups (`bot`, `db`, `dev`, `docker`).
* **[Code Coverage](./docs/content/dev/coverage.md)**
  * Running tests with coverage tracking.
  * Generating and interpreting coverage reports.
  * Using `awbot test run`, `awbot test coverage`, and related commands.
* **[Database Management](./docs/content/dev/database.md)**
  * Detailed usage of `awbot db` commands (push, migrate, generate, pull, reset).
  * Working with Prisma migrations.
* **[Database Controller Patterns](./docs/content/dev/database_patterns.md)**
  * Using controllers for CRUD, transactions, relations.
  * Best practices for database interactions in code.
* **[Docker Environment](./docs/content/dev/docker_development.md)** (Optional)
  * Setting up and using the Docker-based development environment.
  * Running commands within Docker containers.
