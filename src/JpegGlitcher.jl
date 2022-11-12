module JpegGlitcher

using JpegTurbo
using Random: AbstractRNG, default_rng

export glitch

# Relevant link for markers  :https://en.wikipedia.org/wiki/JPEG#Syntax_and_structure
const NOPAYLOAD = [0x00, 0xD8, (0xD0:0xD7)..., 0xD9]

const WITH_VARSIZE = [0xD8, 0xC0, 0xC2, 0xC4, 0xDB, 0xDA, (0xE0:0xEF)..., 0xFE]

#= 
A JPEG image consists of a sequence of segments, each beginning with a marker, each of which begins with a 0xFF byte, followed by a byte indicating what kind of marker it is. Some markers consist of just those two bytes; others are followed by two bytes (high then low), indicating the length of marker-specific payload data that follows. (The length includes the two bytes for the length, but not the two bytes for the marker.) Some markers are followed by entropy-coded data; the length of such a marker does not include the entropy-coded data. Note that consecutive 0xFF bytes are used as fill bytes for padding purposes, although this fill byte padding should only ever take place for markers immediately following entropy-coded scan data (see JPEG specification section B.1.1.2 and E.1.2 for details; specifically "In all cases where markers are appended after the compressed data, optional 0xFF fill bytes may precede the marker").

Within the entropy-coded data, after any 0xFF byte, a 0x00 byte is inserted by the encoder before the next byte, so that there does not appear to be a marker where none is intended, preventing framing errors. Decoders must skip this 0x00 byte. This technique, called byte stuffing (see JPEG specification section F.1.2.3), is only applied to the entropy-coded data, not to marker payload data. Note however that entropy-coded data has a few markers of its own; specifically the Reset markers (0xD0 through 0xD7), which are used to isolate independent chunks of entropy-coded data to allow parallel decoding, and encoders are free to insert these Reset markers at regular intervals (although not all encoders do this).
=#

"""
    glitch(img; rng::AbstractRNG=default_rng(), nflips::Integer=10, quality::Integer=100)

`glitch` will turn an image into a compressed JPEG format with JPEGTurbo.jl and
randomly change some bytes (safe to change) of the encoded image.

## Keyword arguments

- `rng::AbstractRNG`: the random number generator used to select and modify bytes.
- `n::Integer`: the number of bytes to modify.
- `quality::Integer`: the encoding quality of the JPEG (lower gives worse quality).
"""
function glitch(
    img;
    rng::AbstractRNG = default_rng(),
    n::Integer = 10,
    quality::Integer = 100,
)
    0 < quality <= 100 || error("quality should be between 1 and 100.")
    n > 0 || error("number `n` should be positive.")
    # Encode the image into a Vector{UInt8}
    data = jpeg_encode(img; quality)
    # The bytes that are not markers and can be modified.
    mutable_bytes = sizehint!(Int[], length(data) ÷ 100) # We assume at least 1% of the bits will be markers.
    # Iterate over the bytes.
    i = 1
    while i < length(data)
        # 0xFF is possibly the beginning of a marker.
        if data[i] == 0xFF
            i += 1 # We move on the next byte.
            if data[i] ∈ NOPAYLOAD # Marker not followed by extra bites
                nothing
            elseif data[i] == 0xDD # 0xDD is guaranteed to be followed by 4 bytes
                i += 4
            elseif data[i] ∈ WITH_VARSIZE # The next two bytes indicate the size
                # of the data contained by the marker.
                high_byte, low_byte = data[i+1:i+2]
                size = parse(UInt16, bitstring(high_byte) * bitstring(low_byte); base = 2)
                i += size
            end
        else
            push!(mutable_bytes, i) # In the case it's not a marker we add it to the list.
        end
        i += 1
    end
    # Once we completed the list of safe bytes to modify, we get to work!
    for i = 1:n
        loc = rand(rng, mutable_bytes) # Select a random byte.
        data[loc] = rand(rng, 0x00:0xfe) # We pick a new random byte (except 0xff).
    end
    # Finally disencode the data.
    jpeg_decode(data)
end

end
