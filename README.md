# Frieve Editor

Lustre-based editor scaffold for a graph-first note workspace.

## Setup

```sh
gleam deps download
```

## Run

```sh
gleam run -m lustre/dev start
```

## Build

```sh
gleam run -m lustre/dev build --minify
```

The Lustre dev tools use a top-level `assets` directory for static files, and
`gleam.toml` configures `/style.css` through `tools.lustre.html.stylesheets`. A
root `index.html` is included here as an explicit deployment shell.

## Layout

- `src/` contains the Gleam source
- `test/` contains gleeunit tests
- `assets/` contains static CSS
- `.github/workflows/test.yml` runs CI tests
