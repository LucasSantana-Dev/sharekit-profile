# Python CLI Patterns

## Split and refactor CLI commands

When a CLI module grows beyond ~200 lines or has unrelated subcommands, split it by domain.

**Pattern: group commands into sub-modules, register via app factory**

```python
# Before: monolithic cli/commands.py with 400+ lines
# After: cli/ package with one file per domain

# cli/__init__.py
def create_app() -> typer.Typer:
    app = typer.Typer()
    app.add_typer(containers_app, name="containers")
    app.add_typer(config_app, name="config")
    app.add_typer(backup_app, name="backup")
    return app

# cli/containers.py
containers_app = typer.Typer()

@containers_app.command()
def start(name: str): ...
```

**Split boundary signals:**
- Commands that share no state with others → separate module
- Commands that call the same manager → keep together
- File > 250 lines with 5+ commands → split by manager/domain

## Typer + Rich patterns

```python
# Progress feedback without Rich pollution
console = Console()

def deploy(service: str) -> None:
    console.print(f"Deploying {service}...")
    result = manager.deploy(service)
    if result["success"]:
        console.print(f"[green]✓[/green] {result['message']}")
    else:
        console.print(f"[red]✗[/red] {result['error']}", err=True)
        raise typer.Exit(1)
```

## Common refactor moves

| Code smell | Fix |
|---|---|
| `if service == "portainer": ...` repeated | Move logic to manager, pass service name |
| `subprocess.run(...)` in CLI callback | Extract to service layer |
| Global state modified by commands | Inject via factory param or constructor |
| `sys.exit()` in command body | Use `raise typer.Exit(code)` |
| Long `--help` strings inline | Use `typer.Option(..., help="...")` |

## Testing CLI commands

```python
from typer.testing import CliRunner
from myapp.cli import create_app

runner = CliRunner()
app = create_app()

def test_deploy():
    result = runner.invoke(app, ["containers", "deploy", "--service", "nginx"])
    assert result.exit_code == 0
    assert "success" in result.output.lower()
```

Inject fake managers via the app factory's optional params — avoids subprocess calls in tests.
