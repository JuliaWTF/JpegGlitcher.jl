using JpegGlitcher
using Random: Xoshiro
using Test
using TestImages
using ImageIO, FileIO

@testset "JpegGlitcher.jl" begin
    # Test Gray images
    for img_name in ("cameraman", "mountainview")
        @testset "$img_name" begin
            img = testimage(img_name)
            # test alg runs fine
            for kw in ((;), (; quality=10), (; n=100))
                glitched = glitch(img)
                @test size(img) == size(glitched)
                @test eltype(img) == eltype(glitched)
            end
            # test rng consistency
            @test glitch(img; rng=Xoshiro(42)) == glitch(img; rng=Xoshiro(42))
            # test errors
            @test_throws ErrorException glitch(img; quality=-1)
            @test_throws ErrorException glitch(img; quality=101)
            @test_throws ErrorException glitch(img; n=-2)
        end
    end
    @testset "Image in and out" begin
        assets = joinpath(pkgdir(JpegGlitcher), "assets")
        file_in = joinpath(assets, "glitched.png")
        file_out = joinpath(pkgdir(JpegGlitcher), "test", "test_out.png")
        file_out_auto = joinpath(assets, "glitched_glitched.png")
        try
            glitch(file_in, file_out)
            @test isfile(file_out)
            @test load(file_out) isa Matrix
            glitch(file_in)
            @test isfile(file_out_auto)
            @test load(file_out_auto) isa Matrix
        finally
            isfile(file_out) && rm(file_out)
            isfile(file_out_auto) && rm(file_out_auto)
        end
    end
end
