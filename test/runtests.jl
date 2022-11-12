using JpegGlitcher
using Random: Xoshiro
using Test
using TestImages

@testset "JpegGlitcher.jl" begin
    # Test Gray images
    for img_name in ("cameraman", "mountainview")
        @testset "$img_name" begin
            img = testimage(img_name)
            # test alg runs fine
            for kw in ((;), (; quality = 10), (; n = 100))
                glitched = glitch(img)
                @test size(img) == size(glitched)
                @test eltype(img) == eltype(glitched)
            end
            # test rng consistency
            @test glitch(img; rng = Xoshiro(42)) == glitch(img; rng = Xoshiro(42))
            # test errors
            @test_throws ErrorException glitch(img; quality = -1)
            @test_throws ErrorException glitch(img; quality = 101)
            @test_throws ErrorException glitch(img; n = -2)
        end
    end
end
