"""Entrypoint for the awbot Discord bot application."""

from awbot.app import awbotApp


def run() -> None:
    """
    Instantiate and run the awbot application.

    This function is the entry point for the awbot application.
    It creates an instance of the awbotApp class and runs it.
    """

    app = awbotApp()
    app.run()


if __name__ == "__main__":
    run()
