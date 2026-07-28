# Frieve Editor

Lustre-based editor scaffold for a graph-first note workspace.

## Setup

```sh
gleam add lustre
gleam add --dev lustre_dev_tools
```

## Run

```sh
gleam run -m lustre/dev start
```

Lustre’s dev tools use a top-level `assets` directory for static files and can
generate the browser HTML entrypoint during development and build. The styles in
this project are loaded through `tools.lustre.html.stylesheets` in `gleam.toml`.

## Layout

- `src/` contains the Gleam source
- `test/` contains gleeunit tests
- `assets/` contains static CSS
