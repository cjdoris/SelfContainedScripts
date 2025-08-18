# SelfContainedScripts.jl

SelfContainedScripts lets you write self-contained Julia scripts that declare their dependencies inline using [PEP 723–style metadata blocks](https://packaging.python.org/en/latest/specifications/inline-script-metadata/).

## Installation

We recommend you (and anyone who wants to run your scripts) install SelfContainedScripts
in their default global environment:
```bash
julia -e 'using Pkg; Pkg.add(url="https://github.com/cjdoris/SelfContainedScripts.jl.git");'
```

## Example workflow

Let's reproduce `examples/example.jl`.

First, open Julia and run the following:
```julia
using SelfContainedScripts
SelfContainedScripts.init("example.jl")
```

This will create a stub file with this content:
```julia
# /// project
# name = "example"
# ///
using SelfContainedScripts
SelfContainedScripts.activate()

# your code here
```

As well as creating `example.jl`, the `init()` call above created and activated an
ordinary Julia project at `~/.julia/environments/self-contained-scripts/example`. Now
we can modify the project using ordinary `Pkg` functions and then use `sync()` to update
the `project` block in the script.
```julia
using Pkg
Pkg.add("Example")
SelfContainedScripts.sync()
```

Now the script contains the dependency we just added:
```julia
# /// project
# name = "example"
#
# [deps]
# Example = "7876af07-990d-54b4-ab0e-23690620f79a"
# ///
using SelfContainedScripts
SelfContainedScripts.activate()

# your code here
```

Now edit the script to add its main functionality:
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

And you're done! You can run it directly like so:

```bash
julia example.jl
```

Finally, you can share this script with others to run themselves. All they need to do
is install SelfContainedScripts.jl themselves in their global environment.

## If you have an existing script

To "upgrade" an existing script in an existing project:

```julia
Pkg.activate("your-project")

# Initialise the script but stay in the current project.
# You only need to do this once.
SelfContainedScripts.init("your-script.jl", activate=false)

# Sync the current Project.toml into the script.
SelfContainedScripts.sync("your-script.jl")
```

## API
We have these functions:
- `init(script=nothing; activate=true, resolve=true)` creates or updates a script with a
  project block and activation code. Activates the environment unless activate=fasle.
- `activate(script=nothing; resolve=true)` creates or updates a project from the
  embedded project block in the script, activates and resolves it.
- `sync(script=nothing)` copy the currently active Project.toml into the script.

The automatically created Julia project is at `~/.julia/environments/self-contained-scripts/<name>`
where `<name>` is as given in the project block, or is derived from the filename if not
given.

By default these functions work on `script=PROGRAM_FILE` if it is set. The `script` arg
is remembered and reused in future calls if not given, so `init("foo.jl"); sync()` is
equivalent to `init("foo.jl"); sync("foo.jl")`.

See the docstrings for further details.
