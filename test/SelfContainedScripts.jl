using TestItems

@testitem "init creates new script and placeholder" begin
    tmp = mktempdir()
    script = joinpath(tmp, "myscript.jl")
    out = SelfContainedScripts.init(script)
    @test abspath(script) == out
    txt = read(script, String)
    expected = string("# /// project\n",
                      "# name = ", '"', "myscript", '"', "\n",
                      "# ///\n",
                      "using SelfContainedScripts\n",
                      "SelfContainedScripts.activate()\n",
                      "\n",
                      "# your code here\n")
    @test txt == expected
end

@testitem "init inserts block and code above existing content" begin
    tmp = mktempdir()
    script = joinpath(tmp, "x.jl")
    base = string("println(", '"', "hi", '"', ")\n")
    write(script, base)
    out = SelfContainedScripts.init(script; name="custom")
    @test out == abspath(script)
    txt = read(script, String)
    prefix = string("# /// project\n",
                    "# name = ", '"', "custom", '"', "\n",
                    "# ///\n",
                    "using SelfContainedScripts\n",
                    "SelfContainedScripts.activate()\n")
    @test startswith(txt, prefix)
    @test endswith(txt, base)
end

@testitem "init errors if project block exists" begin
    tmp = mktempdir()
    script = joinpath(tmp, "y.jl")
    content = string("# /// project\n",
                     "# name = ", '"', "y", '"', "\n",
                     "# ///\n",
                     "println(", '"', "ok", '"', ")\n")
    write(script, content)
    @test_throws ArgumentError SelfContainedScripts.init(script)
end

@testitem "sync replaces project block from active Project.toml preserving newline style" begin
    const ISM = SelfContainedScripts.InlineScriptMetadata

    tmp = mktempdir()
    script = joinpath(tmp, "s.jl")

    # Create script with a minimal project block but do not activate envs
    out = SelfContainedScripts.init(script; name="s", activate=false, resolve=false)
    @test out == abspath(script)

    # Prepare a temp environment with CRLF Project.toml
    envdir = mktempdir()
    proj = joinpath(envdir, "Project.toml")
    ptxt = string(
        "name = ", '"', "s", '"', "\r\n",
        "[deps]\r\n",
        "ExampleDep = ", '"', "01234567-89ab-cdef-0123-456789abcdef", '"'
    )
    write(proj, ptxt)

    # Activate that environment so Base.active_project() points to proj
    Pkg.activate(envdir)

    # Sync script's project block from active Project.toml
    out2 = SelfContainedScripts.sync(script)
    @test out2 == abspath(script)

    f = read(script, ISM.FileWithMetadata)
    @test haskey(f.blocks, "project")
    @test f.blocks["project"].content == string(ptxt, "\r\n")
end

@testitem "sync errors when project block is missing" begin
    tmp = mktempdir()
    script = joinpath(tmp, "s2.jl")
    write(script, "println(\"x\")\n")

    envdir = mktempdir()
    write(joinpath(envdir, "Project.toml"), "name = \"z\"")
    Pkg.activate(envdir)

    @test_throws ArgumentError SelfContainedScripts.sync(script)
end
