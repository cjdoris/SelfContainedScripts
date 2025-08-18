module SelfContainedScripts

using Pkg
using TOML

public activate, init, sync

include("InlineScriptMetadata.jl")

# Remembered last script file path
global SCRIPT_FILE::String

# Internal helper to resolve and persist the current script file path
function script_file(script::Union{Nothing,AbstractString}=nothing)::String
    if script === nothing
        if @isdefined SCRIPT_FILE
            return SCRIPT_FILE
        end
        sf = Base.PROGRAM_FILE
        if isempty(sf)
            error("not running a script (PROGRAM_FILE is empty)")
        end
        global SCRIPT_FILE = abspath(sf)
        return SCRIPT_FILE
    else
        s = String(script)
        if isempty(s)
            error("script path is empty")
        end
        global SCRIPT_FILE = abspath(s)
        return SCRIPT_FILE
    end
end

"""
    activate(script::Union{Nothing,AbstractString}=nothing; resolve=true) -> String

Activate a self-contained project for `script` defined by an inline `project` metadata block.

The project is at `~/.julia/environments/self-contained-scripts/<name>`.

Returns the absolute path to the generated Project.toml.
"""
function activate(script::Union{Nothing,AbstractString} = nothing; resolve::Bool = true)::String
    script = script_file(script)

    # parse file
    f = read(script, InlineScriptMetadata.FileWithMetadata)

    # extract the project block
    block = get(f.blocks, "project", nothing)
    if block === nothing
        error("no 'project' metadata block found")
    end

    # Derive environment name
    toml = TOML.parse(block.content)
    name = get(toml, "name", nothing)
    if name === nothing
        name = splitext(basename(script))[1]
    elseif !isa(name, String)
        error("project 'name' must be a string")
    end

    # Build paths
    envdir = joinpath(DEPOT_PATH[1], "environments", "self-contained-scripts", name)
    project = joinpath(envdir, "Project.toml")

    # Create and write Project.toml exactly as specified
    mkpath(envdir)
    write(project, block.content)

    # Activate and optional resolve
    Pkg.activate(envdir)
    if resolve
        Pkg.resolve()
    end

    return abspath(project)
end

"""
    init(script::Union{Nothing,AbstractString}=nothing; name=nothing, activate=true, resolve=true) -> String

Create or update `script` by inserting at the very top:

- a minimal `project` metadata block with only `name` (derived from file name when not provided)

- the two bootstrap lines:

  ```
  using SelfContainedScripts
  SelfContainedScripts.activate()
  ```

It is then activated (see (`activate`)[@ref]) unless `activate=false`.

If `script` does not exist, it is created.

Errors if a `project` block already exists.

Returns the absolute path to `script`.
"""
function init(script::AbstractString; name::Union{Nothing,AbstractString}=nothing, activate::Bool=true, resolve::Bool=true)::String
    script = script_file(script)

    # Prepare initial content
    newfile = !isfile(script)
    src = if newfile
        "# your code here\n"
    else
        read(script, String)
    end

    # Decide project name
    pname::String = name === nothing ? splitext(basename(script))[1] : String(name)

    # Insert project block at top using InlineScriptMetadata
    f = parse(InlineScriptMetadata.FileWithMetadata, src)
    if haskey(f.blocks, "project")
        error("script already contains 'project' block")
    end
    f2 = InlineScriptMetadata.add_block_at_top(f, "project", "name = \"$pname\"")

    # Inject the two bootstrap lines immediately after the inserted block; keep the
    # blank line (added by add_block_at_top) between the code and the original content.
    blk = f2.blocks["project"]
    content = f2.content
    head = content[first(blk.block_range):last(blk.block_range)]
    tail_start = nextind(content, last(blk.block_range))
    tail = tail_start <= lastindex(content) ? content[tail_start:end] : ""
    nl = InlineScriptMetadata.newline_str(content)
    code = "using SelfContainedScripts$(nl)SelfContainedScripts.activate()$(nl)"
    final = string(head, code, tail)

    # write back
    write(script, final)

    # activate (optional)
    if activate
        SelfContainedScripts.activate(nothing; resolve=resolve)
    end
    
    return script
end

"""
    sync(script::Union{Nothing,AbstractString}=nothing) -> String

Overwrite the `project` metadata block in `script` with the content of the currently
active Project.toml.

If the `project` block is missing, it is created (and the two bootstrap lines are
inserted) exactly as [`init(script; activate=false)`](@ref init) would do.

Returns the absolute path to the updated script.
"""
function sync(script::Union{Nothing,AbstractString}=nothing)::String
    script = script_file(script)

    # Parse file; if no 'project' block, initialize it with boilerplate (without activation)
    f = read(script, InlineScriptMetadata.FileWithMetadata)
    if !haskey(f.blocks, "project")
        init(script; activate=false)
        f = read(script, InlineScriptMetadata.FileWithMetadata)
        @assert haskey(f.blocks, "project")
    end

    # Locate active Project.toml
    proj = Base.active_project()
    if proj === nothing || !isfile(proj)
        error("no active Project.toml found; activate an environment first")
    end

    # Read active Project.toml content verbatim
    ptxt::String = read(proj, String)

    # Replace the 'project' block content preserving the provided content's newline style
    f2 = InlineScriptMetadata.replace_block_content(f, "project", ptxt)

    # Write back to the script
    write(script, f2.content)

    return abspath(script)
end

end # module SelfContainedScripts
