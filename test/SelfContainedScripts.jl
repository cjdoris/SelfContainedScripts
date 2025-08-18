using TestItems

@testitem "init creates new script and placeholder" begin
    tmp = mktempdir()
    script = joinpath(tmp, "myscript.jl")
    out = SelfContainedScripts.init(script, activate=false)
    @test abspath(script) == out
    txt = read(script, String)
    expected = """
        # /// project
        # name = "myscript"
        # ///
        using SelfContainedScripts
        SelfContainedScripts.activate()

        # your code here
        """
    @test txt == expected
end

@testitem "init inserts block and code above existing content" begin
    tmp = mktempdir()
    script = joinpath(tmp, "x.jl")
    base = string("println(", '"', "hi", '"', ")\n")
    write(script, base)
    out = SelfContainedScripts.init(script; name="custom", activate=false)
    @test out == abspath(script)
    txt = read(script, String)
    prefix = """
        # /// project
        # name = "custom"
        # ///
        using SelfContainedScripts
        SelfContainedScripts.activate()
        """
    @test startswith(txt, prefix)
    @test endswith(txt, base)
end

@testitem "init errors if project block exists" begin
    tmp = mktempdir()
    script = joinpath(tmp, "y.jl")
    content = """
        # /// project
        # name = "y"
        # ///
        println("ok")
        """
    write(script, content)
    @test_throws Exception SelfContainedScripts.init(script, activate=false)
end

@testitem "sync replaces project block from active Project.toml preserving newline style" begin
    const ISM = SelfContainedScripts.InlineScriptMetadata

    tmp = mktempdir()
    script = joinpath(tmp, "s.jl")

    # Create script with a minimal project block but do not activate envs
    out = SelfContainedScripts.init(script; name="s", activate=false)
    @test out == abspath(script)

    # Prepare a temp environment with CRLF Project.toml
    envdir = mktempdir()
    proj = joinpath(envdir, "Project.toml")
    ptxt = """
        name = "s"
        [deps]
        ExampleDep = "01234567-89ab-cdef-0123-456789abcdef"
        """
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
    write(script, """println("x")\n""")

    envdir = mktempdir()
    write(joinpath(envdir, "Project.toml"), """name = "z\"""")
    Pkg.activate(envdir)

    @test_throws ArgumentError SelfContainedScripts.sync(script)
end
