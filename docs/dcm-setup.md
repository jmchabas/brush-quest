# Dart Code Linter Setup

Uses `dart_code_linter` (MIT, open-source fork of dart_code_metrics) for deeper static analysis beyond `dart analyze`.

## Install

Already a dev dependency in `pubspec.yaml`. No global install needed.

## Run

```bash
# Lint rules (configured in analysis_options.yaml under dart_code_metrics:)
dart run dart_code_linter:metrics analyze lib

# Find unused classes, functions, variables
dart run dart_code_linter:metrics check-unused-code lib

# Find parameters that don't need to be nullable
dart run dart_code_linter:metrics check-unnecessary-nullable lib
```

## Configuration

Rules live in `analysis_options.yaml` under the `dart_code_metrics:` section (same file as `dart analyze` config).

## CI

All three checks run in the `analyze` job in `.github/workflows/ci.yml`.

## Notes

- Metrics thresholds (cyclomatic complexity 20, max nesting 5, etc.) are tuned for this project's screen/service pattern where some game logic is inherently branchy.
- The old `analysis_options_dcm.yaml` file is no longer used — config is now merged into the main `analysis_options.yaml`.
