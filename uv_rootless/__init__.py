"""uv-rootless entrypoint."""

import typer

app = typer.Typer()


@app.command()
def hello() -> None:
    """Say hello."""
    typer.echo("Hello, World!")


if __name__ == "__main__":
    app()
