# iOS Calculator

A simple iOS calculator with a muted, earthy UI.

This project is an **experiment in building a real app with a local LLM.**
The primary author is a small on-device model —
**[`qwen3.8:27b-mlx`](https://ollama.com/library/qwen3.8)** (a ~27B-parameter
Ollama model, MLX-quantized for Apple Silicon) — running locally on the laptop
and driving VS Code Copilot. The goal was to see how far a local, non-cloud
model can take a shipping-style app: engine, tests, UI, layout, and git
hygiene — with a human in the loop steering and reviewing.

## Models

All three are **local** Ollama models (no cloud calls). Of the roughly thirteen
recorded model-handoffs, `qwen3.8:27b-mlx` was the clear winner:

| Model | Rough use | Role |
|-------|-----------|------|
| **`qwen3.8:27b-mlx`** | ~54% | The sustained author; ran the bulk of the build |
| **`qwen3-coder:30b`** | ~38%* | Abandoned early |
| **`devstral:24b`** | ~8% | A single one-off |

*The ~38% for `qwen3-coder:30b` is generous: it was abandoned fairly early on
after it handled tool use poorly — it failed to call tools reliably, which made
progress grind to a halt.

## What it is

- **SwiftUI app** that wraps a framework-independent engine.
- **`CalculatorEngine`** — a pure-Swift package holding all calculation logic,
  with no UI dependency and its own test suite (23 tests).
- **`Calculator`** — the SwiftUI front end (`ContentView`) that drives the engine.
- Port of an earlier native macOS/Cocoa calculator (`calculator.mm`), which
  remains in the repo as the reference implementation.

## Layout

```
Calculator/            SwiftUI app + UI
CalculatorEngine/      Pure-Swift engine package (Sources + Tests)
calculator.mm          Original C/Cocoa reference implementation
project.yml            Xcode project is generated from this via XcodeGen
```

## Build & run

The `.xcodeproj` is generated from `project.yml` (XcodeGen):

```sh
xcodegen generate
open Calculator.xcodeproj
```

Or build/test the engine directly from the command line:

```sh
cd CalculatorEngine
swift test
```

## Challenges

The build was not a smooth line. The friction — and what it teaches about
driving a small local model — comes in a few flavors:

- **Delimiter matching.** The most common failure was mismatched braces and
  parentheses — small structural drift a 27B model introduces when rewriting
  multi-line Swift. Several sessions were spent repairing `CalculatorEngine.swift`
  and the Xcode project after the model left them unbalanced.
- **Getting stuck.** The model sometimes produced the same output repeatedly
  without progress; getting it unstuck took "Try Again" prompts and, at times,
  a mid-task handoff to another model.
- **A `.gitignore` footgun.** An entry for the compiled macOS binary
  (`/calculator`) matched case-insensitively on the macOS filesystem and
  silently swallowed the `Calculator/` source folder, so `git add` staged
  nothing. Fixed by tightening the ignore pattern.
- **Off-by-one logic bugs in the app.** The thousand-separator was originally
  grouped from the left (`1000000` → `100,000,0`); it now groups from the
  right. Separately, `=` used to drop the final operand from the expression
  line. Both surfaced through the unit tests — the point being that a 23-test
  suite catches what a one-shot model does not.
- **Human in the loop.** Across ~11 sessions the model was steered, reviewed,
  and occasionally restarted by hand — the loop a local model needs to reach a
  real, working app.

## License

MIT — see `LICENSE`.
