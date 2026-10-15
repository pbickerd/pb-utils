# CLAUDE.md

This repository is a personal collection of tools used day-to-day for work. Tools are written mostly in **Bash**, **Python** and **Go**.

## Repository layout

Tools are grouped into category folders. Each tool lives in its own subfolder inside a category.

```
pb-utils/
├── README.md                  # Top-level index: links to each category folder
├── CLAUDE.md
├── kubernetes/
│   ├── README.md              # Category index: links to each tool in this folder
│   ├── some-tool/
│   │   ├── README.md          # Tool documentation
│   │   └── some-tool.sh
│   └── another-tool/
│       ├── README.md
│       └── main.go
└── <category>/
    └── ...
```

- Category folder names are lowercase and hyphenated (e.g. `kubernetes`, `aws`, `git`, `networking`).
- Tool folder names are lowercase and hyphenated, and match the tool's command name where possible.

## Documentation rules

There are three levels of README, and they must be kept in sync whenever tools or categories are added, renamed or removed.

### 1. Root `README.md` — index of categories
- Lists every category folder with a link and a one-line description.
- Keep entries in alphabetical order.

### 2. Category `README.md` — index of tools
- Short description of what the category covers.
- Lists every tool in the folder with a link to its folder, its language, and a one-line description.
- Keep entries in alphabetical order.

### 3. Tool `README.md` — tool documentation
Every tool must have a README containing:
- **Name and one-line summary**
- **Requirements** — runtime/language version, external CLIs (e.g. `kubectl`, `jq`, `aws`), required env vars or credentials
- **Install / build** — e.g. `go build`, `pip install -r requirements.txt`, or "none" for plain scripts
- **Usage** — command syntax, flags/arguments, and at least one example
- **Notes** — caveats, side effects (especially anything destructive), known limitations

## Adding a new tool

1. Create `<category>/<tool-name>/` (create the category folder if it doesn't exist).
2. Add the tool's source and its `README.md`.
3. Add the tool to `<category>/README.md`.
4. If the category is new, create its `README.md` and add it to the root `README.md`.

## Language conventions

### Bash
- Start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Make scripts executable (`chmod +x`).
- Provide `-h`/`--help` usage output.
- Should pass `shellcheck`.

### Python
- Target Python 3; start scripts with `#!/usr/bin/env python3`.
- Use `argparse` for CLI arguments.
- Keep each tool self-contained; if it has dependencies, list them in a `requirements.txt` in the tool's folder.
- Format with `ruff format` / lint with `ruff check` where available.

### Go
- Each Go tool is its own module with its own `go.mod` in the tool folder.
- Format with `gofmt`; check with `go vet`.
- Don't commit built binaries.

## General principles
- Tools should be self-contained within their folder — no cross-tool dependencies unless unavoidable.
- Never hard-code secrets, tokens or environment-specific hostnames; use env vars or flags.
- Tools that make destructive changes should support a dry-run mode or require confirmation.
