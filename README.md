# JpegGlitcher

It's glitching time!

`JpegGlitcher` only exports the `glitch` function.
`glitch` takes an image, compresses it using the JPEG encoding, safely modifies
some bytes of the compressed version and return the decoded version.

Here is a basic example, using the default parameters.

```julia
using JpegGlitcher
using Random, FileIO, TestImages

img = testimage("mountainview")
glitch(img)
```

![Glitched version of the Mountain View image](assets/glitched.png)

We can also make an animation, playing with the different parameters!

```julia
cat([glitch(img; rng = Random.Xoshiro(42), n = i, quality = 20) for i in 1:50]...; dims=3)
```

![Low quality animated glitching](assets/glitched_anim.gif)
