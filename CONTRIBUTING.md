# Contributing

Small fixes, clear bug reports, and useful widget ideas are welcome. For a large feature, open an issue describing the problem and the proposed interaction before building it.

## Development

Run `./scripts/build.sh` and open `build/Perch.app`. Use `swift test` for behavior changes. The `--demo` launch argument uses synthetic data and disables persistent saves and live account operations.

Keep UI changes consistent with [DESIGN.md](DESIGN.md) and the [dock brief](docs/panel-brief.md). Check light and dark appearances, long text, empty states, keyboard access, and all affected dock edges. Keep backgrounds quiet and controls legible in the small panels.

## Data is a compatibility contract

Read [AGENTS.md](AGENTS.md). Preserve the bundle identifier and data location. Add defaults for new fields, back up before migrations, and test prior-format fixtures. Keep save failures visible. An update must not discard a draft or overwrite another running copy’s data.

Add tests for behavior and fixes with meaningful failure cases. Run `swift test` and `git diff --check`. Release and installer changes also need the isolated installer suite described in [RELEASING.md](docs/RELEASING.md).

## Pull requests

Explain the concrete problem, the new behavior, and how you checked it. Include screenshots for visible changes and note anything you could not test. Keep unrelated edits separate. Do not include personal data, credentials, build output, or private screenshots.

By contributing, you agree to license your contribution under this project’s MIT license.
