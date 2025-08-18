module SelfContainedScripts

include("InlineScriptMetadata.jl")
using .InlineScriptMetadata
using Pkg
using TOML

public activate, init

"""
    activate(script::AbstractString=Base.PROGRAM_FILE; resolve=true) -> String

Activate a self-contained project for `script` defined by an inline `project` metadata block.

The project is at ~/.julia/environments/self-contained-scripts/<name>.

Returns the absolute path to the generated Project.toml after activation (and resolve when enabled).
"""
function activate(script::AbstractString = Base.PROGRAM_FILE; resolve::Bool = true)::String
    if isempty(script)
        error("not running a script (PROGRAM_FILE is empty)")
    end

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
    init(script::AbstractString; name=nothing, activate=true, resolve=true) -> String

Create or update `script` by inserting at the very top:
- a minimal 'project' metadata block with only `name` (derived from file name when not provided)
- the two bootstrap lines:
  using SelfContainedScripts
  SelfContainedScripts.activate()

If `script` does not exist, it is created and a '# your code here' placeholder is appended after the two lines.
Error if a 'project' block already exists.

When activate=false, no environment activation occurs. When resolve=false, it is passed to activate(), skipping dependency resolution.

Returns the absolute path to `script`.
"""
function init(script::AbstractString; name::Union{Nothing,AbstractString}=nothing, activate::Bool=true, resolve::Bool=true)::String
    if isempty(script)
        error("script path is empty")
    end

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
    code = "using SelfContainedScripts\nSelfContainedScripts.activate()\n"
    final = string(head, code, tail)

    # write back
    write(script, final)

    # activate (optional)
    if activate
        SelfContainedScripts.activate(script; resolve=resolve)
    end
    
    return script
end

end # module SelfContainedScripts
