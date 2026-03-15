module JpegGlitcher

using JpegTurbo
using Random: AbstractRNG, default_rng
using StatsBase: sample
using PrecompileTools: @setup_workload, @compile_workload
using ImageIO
using FileIO

export glitch

# Relevant link for markers  :https://en.wikipedia.org/wiki/JPEG#Syntax_and_structure
const NOPAYLOAD = [0x00, 0xD8, (0xD0:0xD7)..., 0xD9]

const WITH_VARSIZE = [0xC0, 0xC2, 0xC4, 0xDB, 0xDA, (0xE0:0xEF)..., 0xFE]

#= 
A JPEG image consists of a sequence of segments, each beginning with a marker, each of which begins with a 0xFF byte, followed by a byte indicating what kind of marker it is. Some markers consist of just those two bytes; others are followed by two bytes (high then low), indicating the length of marker-specific payload data that follows. (The length includes the two bytes for the length, but not the two bytes for the marker.) Some markers are followed by entropy-coded data; the length of such a marker does not include the entropy-coded data. Note that consecutive 0xFF bytes are used as fill bytes for padding purposes, although this fill byte padding should only ever take place for markers immediately following entropy-coded scan data (see JPEG specification section B.1.1.2 and E.1.2 for details; specifically "In all cases where markers are appended after the compressed data, optional 0xFF fill bytes may precede the marker").

Within the entropy-coded data, after any 0xFF byte, a 0x00 byte is inserted by the encoder before the next byte, so that there does not appear to be a marker where none is intended, preventing framing errors. Decoders must skip this 0x00 byte. This technique, called byte stuffing (see JPEG specification section F.1.2.3), is only applied to the entropy-coded data, not to marker payload data. Note however that entropy-coded data has a few markers of its own; specifically the Reset markers (0xD0 through 0xD7), which are used to isolate independent chunks of entropy-coded data to allow parallel decoding, and encoders are free to insert these Reset markers at regular intervals (although not all encoders do this).
=#

# Advance past a JPEG marker. `i` points to the marker-type byte (immediately after 0xFF).
# Returns the updated index after skipping the full marker segment.
function skip_marker(data::Vector{UInt8}, i::Int)
    if data[i] ∈ NOPAYLOAD
        i
    elseif data[i] == 0xDD  # DRI: fixed 4-byte payload
        i + 4
    elseif data[i] ∈ WITH_VARSIZE
        i + (UInt16(data[i+1]) << 8 | UInt16(data[i+2]))
    else
        i
    end
end

# Count the number of mutable (non-marker) bytes in encoded JPEG data.
function count_mutable(data::Vector{UInt8})
    n = 0
    i = 1
    while i < length(data)
        if data[i] == 0xFF
            i = skip_marker(data, i + 1)
        else
            n += 1
        end
        i += 1
    end
    n
end

"""
    glitch(img::AbstractMatrix; rng::AbstractRNG=default_rng(), nflips::Integer=10, quality::Integer=100)

`glitch` will turn an image into a compressed JPEG format with JPEGTurbo.jl and
randomly change some bytes (safe to change) of the encoded image.

## Keyword arguments

- `rng::AbstractRNG`: the random number generator used to select and modify bytes.
- `nflips::Integer`: the number of bytes to modify.
- `quality::Integer`: the encoding quality of the JPEG (lower gives worse quality).
"""
function glitch(
    img::AbstractMatrix{T};
    rng::AbstractRNG=default_rng(),
    nflips::Integer=10,
    quality::Integer=100,
) where {T}
    0 < quality <= 100 || error("quality should be between 1 and 100.")
    nflips > 0 || error("`nflips` should be positive.")
    data = jpeg_encode(img; quality)

    # Pass 1: count how many bytes are safe to modify.
    m = count_mutable(data)
    m == 0 && error("No mutable bytes found in encoded image.")
    nflips > m && error("`nflips` ($nflips) exceeds the number of mutable bytes ($m).")

    # Sample nflips unique ranks without replacement, sorted for a single linear pass.
    targets = sample(rng, 1:m, nflips; replace=false, ordered=true)

    # Pass 2: walk the data again and flip only the chosen bytes.
    mutable_count = 0
    t = 1
    i = 1
    while i < length(data)
        if data[i] == 0xFF
            i = skip_marker(data, i + 1)
        else
            mutable_count += 1
            if mutable_count == targets[t]
                data[i] = rand(rng, 0x00:0xfe)
                t += 1
                t > nflips && break
            end
        end
        i += 1
    end
    # Finally disencode the data. We disable stderr, as jpegturbo produces a lot of noise.
    redirect_stdio(; stdout = devnull, stderr = devnull) do
        jpeg_decode(T, data)
    end
end


"""
    glitch(file_in::AbstractString, file_out::AbstractString = auto_glitch_name(file_in); rng::AbstractRNG=default_rng(), nflips::Integer=10, quality::Integer=100)

Glitch image from `file_in` and write the output in `file_out`.
See other method signature for keyword usage.
    
"""
function glitch(
    file_in::AbstractString,
    file_out::AbstractString=auto_glitch_name(file_in);
    kwargs...
)
    img = FileIO.load(file_in)
    glitched_img = glitch(img; kwargs...)
    FileIO.save(file_out, glitched_img)
end

"Automatically append `_glitched` to the original file name."
function auto_glitch_name(path::AbstractString)
    path, ext = splitext(path)
    string(path, "_glitched", ext)
end


@setup_workload begin
    using FileIO, ImageIO
    file = joinpath(pkgdir(JpegGlitcher), "assets", "glitched.png")
    @compile_workload begin
        glitch(file)
    end
end

end
