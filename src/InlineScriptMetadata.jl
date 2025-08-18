module InlineScriptMetadata

# Internal submodule for parsing inline metadata blocks (PEP 723 style).
# Uses concrete types in the internal API.

struct MetadataBlock
    type::String
    block_range::UnitRange{Int}   # indices in original source covering the whole block (markers inclusive)
    content_range::UnitRange{Int} # indices in original source covering the raw commented content
    content::String               # stripped content (leading "# " or "#" removed per line)
end

struct FileWithMetadata
    content::String
    blocks::Dict{String,MetadataBlock}
end

# Official regex (adapted to Julia's named captures):
# (?m)^# /// (?P<type>[a-zA-Z0-9-]+)$\s(?P<content>(^#(| .*)$\s)+)^# ///$
# Notes:
# - (?m) multiline to make ^ and $ match line boundaries.
# - We use (?<name>...) for named captures in Julia.
# - (*ANYCRLF) to allow any newline sequence (\n, \r, \r\n)
# - \R captures the actual newline sequence, instead of \s which only captures one char
const METADATA_REGEX =
    r"(*ANYCRLF)(?m)^# /// (?<type>[a-zA-Z0-9-]+)$\R(?<content>(^#(| .*)$\R)+)^# ///$\R?"

function Base.parse(::Type{FileWithMetadata}, src::String)
    blocks = Dict{String,MetadataBlock}()
    for m in eachmatch(METADATA_REGEX, src)
        t = String(m[:type])
        if haskey(blocks, t)
            throw(ArgumentError("Duplicate metadata block of type '$t'"))
        end

        # Whole block range
        block_start = m.offset
        block_end = prevind(src, block_start + ncodeunits(m.match))
        block_rng = block_start:block_end

        # Raw content capture (commented lines) and its range in the original string
        raw_content = m[:content]::SubString{String}
        content_start = m.offsets[2]  # start index of 'content' capture in original string
        content_end = prevind(src, content_start + ncodeunits(raw_content))
        content_rng = content_start:content_end
        # Strip leading "# " or "#" per line, preserving the rest verbatim
        stripped = replace(String(raw_content), r"(*ANYCRLF)(?m)^# ?" => "")

        blocks[t] = MetadataBlock(t, block_rng, content_rng, stripped)
    end
    return FileWithMetadata(src, blocks)
end

function Base.read(io::IO, ::Type{FileWithMetadata})
    s::String = read(io, String)
    return parse(FileWithMetadata, s)
end

function newline_str(code::String)
    if occursin("\r\n", code)
        "\r\n"
    elseif occursin("\n", code)
        "\n"
    elseif occursin("\r", code)
        "\r"
    else
        "\n"
    end
end

function add_block_at_top(f::FileWithMetadata, t::AbstractString, content::AbstractString)::FileWithMetadata
    t = String(t)
    if haskey(f.blocks, t)
        throw(ArgumentError("Duplicate metadata block of type '$t'"))
    end

    # Preprocess: ensure exactly one trailing newline in the raw content
    c = String(content)
    nl = newline_str(c)
    if !endswith(c, "\n") && !endswith(c, "\r")
        c *= nl
    end
    # Prefix '# ' at the start of every line using a regex (no manual splitting)
    commented = replace(c, r"(*ANYCRLF)(?m)^" => "# ")

    # Build via IOBuffer as requested
    io = IOBuffer()
    print(io, "# /// ", t, nl)
    write(io, commented)          # commented includes its trailing newline
    print(io, "# ///", nl)
    print(io, nl)                   # blank line after the block to separate from following content
    write(io, f.content)
    new_src = String(take!(io))

    # Parse back and validate
    f2 = parse(FileWithMetadata, new_src)

    if !haskey(f2.blocks, t)
        error("internal error: inserted block not found after parse")
    end

    expected_keys = Set(keys(f.blocks))
    push!(expected_keys, t)
    if Set(keys(f2.blocks)) != expected_keys
        error("internal error: parsed blocks after insertion do not match expectation")
    end

    # After stripping, the content should equal the normalized input (with one trailing newline)
    if f2.blocks[t].content != c
        error("internal error: inserted block content mismatch")
    end

    return f2
end

# Replace the content of an existing block identified by its type.
function replace_block_content(f::FileWithMetadata, t::AbstractString, content::AbstractString)::FileWithMetadata
    t = String(t)
    blk = get(f.blocks, t, nothing)
    if blk === nothing
        throw(ArgumentError("No metadata block of type '$t' to replace"))
    end

    # Normalize raw content to include exactly one trailing newline,
    # using the newline style of the provided content.
    c = String(content)
    nl = newline_str(c)
    if !endswith(c, "\n") && !endswith(c, "\r")
        c *= nl
    end

    # Prefix '# ' at the start of every line
    commented = replace(c, r"(*ANYCRLF)(?m)^" => "# ")

    # Splice into original source replacing only the commented content range
    src = f.content
    i = first(blk.content_range)
    j = last(blk.content_range)
    head = i > firstindex(src) ? src[firstindex(src):prevind(src, i)] : ""
    tail = j < lastindex(src) ? src[nextind(src, j):end] : ""
    new_src = string(head, commented, tail)

    # Re-parse and validate
    f2 = parse(FileWithMetadata, new_src)
    if Set(keys(f2.blocks)) != Set(keys(f.blocks))
        error("internal error: parsed blocks after replacement do not match expectation")
    end
    if f2.blocks[t].content != c
        error("internal error: replaced block content mismatch")
    end
    return f2
end

end # module InlineScriptMetadata
