# DCM (Dart Code Metrics) Setup

## Install

```bash
dart pub global activate dcm
```

Make sure `~/.pub-cache/bin` is on your PATH.

## Run

Analyze the project using the custom config:

```bash
dcm analyze lib --options analysis_options_dcm.yaml
```

Check for unused code:

```bash
dcm check-unused-code lib --options analysis_options_dcm.yaml
```

Check for unnecessary nullable parameters:

```bash
dcm check-unnecessary-nullable lib --options analysis_options_dcm.yaml
```

## Notes

- DCM free tier includes the rules configured in `analysis_options_dcm.yaml`.
- The config is kept separate from `analysis_options.yaml` so it does not interfere with `dart analyze`.
- Metrics thresholds (cyclomatic complexity 20, max nesting 5, etc.) are tuned for this project's screen/service pattern where some game logic is inherently branchy.
