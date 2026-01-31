# WinPick Script Format

This repository uses a standardized metadata header and optional undo
support across script types. The templates in `WindowsScripts/Script Templates`
are the canonical reference.

## Supported script types

- Python (`.py`)
- PowerShell (`.ps1`)
- Batch (`.bat` / `.cmd`)

## Metadata header (required)

All scripts begin with a metadata header in comments so the WinPick
application can display script information.

### Python and PowerShell

```
# NAME: Friendly Script Name
# DESCRIPTION: Detailed description of what the script does
# UNDOABLE: Yes/No
# UNDO_DESC: Description of what the undo action does (if applicable)
```

### Batch

```
::: NAME: Friendly Script Name
::: DESCRIPTION: Detailed description of what the script does
::: UNDOABLE: Yes/No
::: UNDO_DESC: Description of what the undo action does (if applicable)
```

### Optional metadata fields

Some scripts and templates also include:

```
# DEVELOPER: Name/handle (optional)
# LINK: URL (optional)
```

Batch uses the same fields with `:::` comment prefixes.

## Undo support (optional)

If `UNDOABLE: Yes`, scripts should implement an undo path and accept
the undo trigger via command-line parameters:

- Python: `--undo`
- PowerShell: `-Undo`
- Batch: `undo` as the first parameter

## Common structure (templates)

Templates include a consistent flow that you can follow or simplify:

1. Metadata header
2. Argument parsing (undo/verbose)
3. Logging setup
4. Optional backup/restore helpers (for undo)
5. Main action function
6. Undo function (when supported)
7. Error handling

## Reference templates

- `WindowsScripts/Script Templates/Template.py`
- `WindowsScripts/Script Templates/Template.ps1`
- `WindowsScripts/Script Templates/Template.bat`
