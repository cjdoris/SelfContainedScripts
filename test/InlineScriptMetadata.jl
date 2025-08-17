using TestItems

@testitem "parse cases" begin
    const ISM = SelfContainedScripts.InlineScriptMetadata

    cases = [
        (
            name = "single project block parse (LF)",
            src = """
                # preface
                # /// project
                # name = "foo"
                # [deps]
                # ExampleDep = "01234567-89ab-cdef-0123-456789abcdef"
                # ///
                # trailing
                """,
            expected = Dict("project" => """
                                name = "foo"
                                [deps]
                                ExampleDep = "01234567-89ab-cdef-0123-456789abcdef"
                                """),
            test_io = false,
        ),
        (
            name = "leading hash stripping variants",
            src = """
                # /// project
                # foo
                #  bar
                # baz
                #
                # ///
                """,
            expected = Dict("project" => """
                                foo
                                 bar
                                baz
                                
                                """),
            test_io = false,
        ),
        (
            name = "multiple distinct block types are keyed separately",
            src = """
                # /// tool
                # hello = "world"
                # ///

                # /// project
                # name = "bar"
                # ///
                """,
            expected = Dict("tool" => """
                                hello = "world"
                                """, "project" => """
                                         name = "bar"
                                         """),
            test_io = false,
        ),
        (
            name = "one explicit blank content line",
            src = """
                # /// project
                #
                # ///
                """,
            expected = Dict("project" => "\n"),
            test_io = false,
        ),
    ]

    @testset "$(case.name)" for case in cases
        f = parse(ISM.FileWithMetadata, case.src)
        # Keys match exactly what we expect
        @test sort(collect(keys(f.blocks))) == sort(collect(keys(case.expected)))

        # Validate every expected block
        for (t, exp) in case.expected
            @test haskey(f.blocks, t)
            blk = f.blocks[t]
            # Content equality
            @test blk.content == exp
            # Stripping from the original source matches content
            @test replace(case.src[blk.content_range], r"(*ANYCRLF)(?m)^# ?" => "") == exp
            # Block text begins and ends with the expected markers
            block_txt = case.src[blk.block_range]
            @test startswith(block_txt, "# /// $t")
            @test endswith(block_txt, "# ///")
        end

        if case.test_io
            io = IOBuffer(case.src)
            f2 = read(io, ISM.FileWithMetadata)
            @test f2.content == case.src
            # Compare all parsed contents
            @test sort(collect(keys(f2.blocks))) == sort(collect(keys(case.expected)))
            for (t, exp) in case.expected
                @test f2.blocks[t].content == exp
            end
        end
    end
end

@testitem "failure cases" begin
    const ISM = SelfContainedScripts.InlineScriptMetadata

    src = """
        # /// project
        # name = "a"
        # ///
        other text
        # /// project
        # name = "b"
        # ///
        """
    @test_throws ArgumentError parse(ISM.FileWithMetadata, src)
end
