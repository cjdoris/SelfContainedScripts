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
