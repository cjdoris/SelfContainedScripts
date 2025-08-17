module SelfContainedScripts

include("InlineScriptMetadata.jl")
using .InlineScriptMetadata
using Pkg
using TOML

public activate

"""
    activate(script::AbstractString=Base.PROGRAM_FILE) -> String

Activate a self-contained project for `script` defined by an inline `project` metadata block.

The project is at ~/.julia/environments/self-contained-scripts/<name>.

Returns the absolute path to the generated Project.toml after activation and resolve.
"""
function activate(script::AbstractString = Base.PROGRAM_FILE)::String
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

    # Activate and resolve
    Pkg.activate(envdir)
    Pkg.resolve()

    return abspath(project)
end

end # module SelfContainedScripts
