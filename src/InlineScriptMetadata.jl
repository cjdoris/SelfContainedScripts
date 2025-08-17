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
    r"(*ANYCRLF)(?m)^# /// (?<type>[a-zA-Z0-9-]+)$\R(?<content>(^#(| .*)$\R)+)^# ///$"

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

end # module InlineScriptMetadata
