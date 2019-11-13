module Animations #end

export Animation, loopanim_callback

using ..SDLGamesLib

# For Animation
using ..SDLGamesLib: SDL2, AbstractPos, Camera, render
# For Sprite
using ..SDLGamesLib: ScreenPixelPos, ScreenPixelDims

# No-op callback
noop(_...) = nothing

"""
    Animation(frames, delays[, donecallback])

Construct an animation that proceeds through `frames` via [`update!(a, dt)`](@ref), with
each frame last for the length of time specified in delays (in seconds).

When the animation finishes, the `donecallback` is invoked as `donecallback(anim, rem_dt)`.
The default `donecallback` is a no-op. You can write your own, or pass one of the callbacks
provided here:
 - [`loopanim_callback`](@ref): Loop the animation forever, restarting when it is completed:
   e.g. `Animation(frames, delays, loopanim_callback)`.
"""
mutable struct Animation
    frames::Vector
    delays::Vector{Float32}
    donecallback  #  will be called as donecallback(self, remaining_dt)

    cur_frame::Int
    cur_frame_delay::Float32
    completed::Bool

    function Animation(frames, delays, donecallback = noop)
        @assert length(frames) == length(delays)
        reset_anim!(new(frames, delays, donecallback))
    end
end

function reset_anim!(a)
    a.cur_frame = 1
    a.cur_frame_delay = 0
    a.completed = false
    a
end
loopanim_callback(a, dt) = update!(reset_anim!(a), dt)

iscompleted(a::Animation) = a.completed

function SDLGamesLib.render(a::Animation, pos::AbstractPos{C}, cam::Camera, renderer;
                size) where C
    render(a.frames[a.cur_frame], pos, cam, renderer; size=size)
end
function SDLGamesLib.update!(a::Animation, dt)
    a.cur_frame_delay += dt

    if iscompleted(a)
        return
    end

    # (while-loop instead of if-statement to account for dt larger than one frame)
    # (Note: `>=` matches exactly the expected delay)
    while a.cur_frame_delay >= a.delays[a.cur_frame]  # tick to next frame if enough time elapsed
        # Reel the animation forward by the delay for the current frame
        a.cur_frame_delay -= a.delays[a.cur_frame]

        # Don't tick the cur_frame beyond the last frame.
        if a.cur_frame >= length(a.frames)
            a.completed = true  # Only run the donecallback once
            a.donecallback(a, a.cur_frame_delay)
            return
        end

        a.cur_frame += 1
    end
end

# -----------------------------------------------------------------------------------------

struct Sprite
    img::Ptr{SDL2.Texture}
    pos::ScreenPixelPos
    dims::ScreenPixelDims
end

function SDLGamesLib.render(s::Sprite, pos::AbstractPos{C}, cam::Camera, renderer;
                size = nothing) where C
    src_rect=SDL2.Rect(s.pos..., s.dims...)
    render(s.img, pos, cam, renderer;
               size=size,
               src_rect=pointer_from_objref(src_rect),)
end

function load_bmp(renderer, file)
    surface = SDL2.LoadBMP(file)
    texture = SDL2.CreateTextureFromSurface(renderer, surface) # Will be C_NULL on failure.
    SDL2.FreeSurface(surface)
    texture
end

end
