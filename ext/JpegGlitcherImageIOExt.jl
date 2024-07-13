module JpegGlitcherImageIOExt

using ImageIO
using FileIO
using JpegGlitcher
using Random: AbstractRNG, default_rng

"""
    glitch(file_in::AbstractString, file_out::AbstractString; rng::AbstractRNG=default_rng(), nflips::Integer=10, quality::Integer=100)

Glitch image from `file_in` and write the output in `file_out`.
See other method signature for keyword usage.
"""
function JpegGlitcher.glitch(
    file_in::AbstractString,
    file_out::AbstractString;
    rng::AbstractRNG=default_rng(),
    n::Integer=10,
    quality::Integer=100,
)
    img = FileIO.load(file_in)
    glitched_img = glitch(img; rng, n, quality)
    FileIO.save(file_out, glitched_img)
end

end