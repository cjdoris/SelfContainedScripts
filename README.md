# SelfContainedScripts.jl

SelfContainedScripts lets you write self-contained Julia scripts that declare their environment inline using [PEP 723–style metadata blocks](https://packaging.python.org/en/latest/specifications/inline-script-metadata/). Call `SelfContainedScripts.activate()` in your script to create and activate a dedicated project for that script.

The project is stored at `~/.julia/environments/self-contained-scripts/<name>` where `<name>` is taken from the `name` in your inline `Project.toml` block, or falls back to the script filename (without extension).

## Example

The following is a complete, runnable example (copied from `examples/example.jl`):

```julia
# /// project
# name = "example"
# 
# [deps]
# Example = "7876af07-990d-54b4-ab0e-23690620f79a"
# ///

using SelfContainedScripts
SelfContainedScripts.activate()

using Example
@show Example.hello("Alice")
```

Run it directly:

```bash
julia examples/example.jl
```

## What `activate()` does

- Reads the script’s inline `project` metadata block delimited by:
  - `# /// project` … `# ///`
- Creates (or reuses) the project at:
  - `~/.julia/environments/self-contained-scripts/<name>`
- Writes the block’s contents to `Project.toml` in that directory
- Activates the environment and runs `Pkg.resolve()`
- Returns the absolute path to the generated `Project.toml`
