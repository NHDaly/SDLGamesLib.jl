# Defines structures and functions relating to display.

export ScreenCoords, ScreenPixelCoords, ScreenPixelPos, ScreenPixelDims,
        UIPixelCoords, UIPixelPos, UIPixelDims, Camera, dpiScale, worldScale,
        screenCenter, screenCenterX, screenCenterY, screenOffsetFromCenter,
        winWidth, winHeight, winWidth_highDPI, winHeight_highDPI,
        toScreenPos, toScreenPixelDims, toUIPixelPos, toUIPixelDims,
        SetRenderDrawColor, blendAlphaColors, topLeftPos, rectOrigin, render,
        renderRectCentered, renderRectFromOrigin, renderText, renderTextSurface,
        createText, sizeText, hcat_render_text, loadFont, render

""" Coordinate system to represent the screen, not the Game World.
Importantly, these are "upside-down" from WorldCoords: (0,0) is top-left, and
higher numbers go down and to the right.
"""
abstract type ScreenCoords end

""" ScreenPixelCoords are absolute space on screen, in actual pixels. """
struct ScreenPixelCoords <: ScreenCoords end

"""
    ScreenPixelPos(1200, 1150)
Absolute position on screen, in pixels. (0,0) is top-left of screen.
"""
struct ScreenPixelPos <: AbstractPos{ScreenPixelCoords}  # 0,0 == top-left
    x::Int
    y::Int
end
ScreenPixelPos(x::Number, y::Number) = ScreenPixelPos(convert.(Int, floor.((x,y)))...)

# TODO: CONSIDER SWITCHING TO DOWN-SCALING INSTEAD of up-scaling, so you can get
# more precise sizes (1.5 "pixels" -> 3 pixels). Or consider using Floats for UIPixelCoords.
""" UIPixelCoords are space on screen, in un-dpi-scaled "pixels". """
struct UIPixelCoords <: ScreenCoords end

"""
    UIPixelPos(400, 450)
Position on screen, in un-dpi-scaled "pixels". (0,0) is top-left of screen.

These should be used whenever placing anything on the screen, since they are
indepdent of resolution-scaling.
"""
struct UIPixelPos <: AbstractPos{UIPixelCoords}  # 0,0 == top-left
    x::Int
    y::Int
end
UIPixelPos(x::Number, y::Number) = UIPixelPos(convert.(Int, floor.((x,y)))...)

+(a::UIPixelPos, b::UIPixelPos) = UIPixelPos(a.x+b.x, a.y+b.y)
# TODO: How to define .+ like this in Julia 1.0+?
#.+(a::UIPixelPos, x::Number) = UIPixelPos(a.x+x, a.y+x)
+(a::UIPixelPos, x::Number) = UIPixelPos(a.x+x, a.y+x)


""" Absolute size on screen, in pixels. Use with ScreenPixelPos. """
struct ScreenPixelDims <: AbstractDims{ScreenPixelCoords}
    w::Int32  # Int32 to match SDL
    h::Int32
end
""" Size on screen, in un-dpi-scaled "pixels". Use with UIPixelPos. """
struct UIPixelDims <: AbstractDims{UIPixelCoords}
    w::Int
    h::Int
end

mutable struct Camera
    pos::WorldPos
    # Note, these are in WorldPos size.
    w::Threads.Atomic{Float32}   # Note: These are Atomics, since they can be modified by the
    h::Threads.Atomic{Float32}   # windowEventWatcher callback, which can run in another thread!
end
Camera() = Camera(WorldPos(0,0),100,100)

# Note: These are all Atomics, since they can be modified by the
# windowEventWatcher callback, which can run in another thread!
winWidth, winHeight = Threads.Atomic{Int32}(800), Threads.Atomic{Int32}(600)
winWidth_highDPI, winHeight_highDPI = Threads.Atomic{Int32}(800), Threads.Atomic{Int32}(600)

screenCenter() = UIPixelPos(winWidth[]/2, winHeight[]/2)
screenCenterX() = winWidth[]/2
screenCenterY() = winHeight[]/2
screenOffsetFromCenter(x::Int,y::Int) = UIPixelPos(screenCenterX()+x,screenCenterY()+y)

dpiScale() = winWidth_highDPI[] / winWidth[];
worldScale(c::Camera) = dpiScale() * (winWidth[] / c.w[]);
function toScreenPos(p::WorldPos, c::Camera)
    scale = worldScale(c)
    ScreenPixelPos(
        round(winWidth_highDPI[]/2. + scale*(p.x-c.pos.x)), round(winHeight_highDPI[]/2. - scale*(p.y-c.pos.y)))
end
function toScreenPos(p::UIPixelPos, c::Camera)
    scale = dpiScale()
    ScreenPixelPos(round(scale*p.x), round(scale*p.y))
end
toScreenPos(p::ScreenPixelPos, c::Camera) = p
function toWorldPos(p::ScreenPixelPos, c::Camera)
    scale = worldScale(c)
    WorldPos((p.x - winWidth_highDPI[]/2.)/scale + c.pos.x, -(p.y - winHeight_highDPI[]/2.)/scale + c.pos.y)
end
function toWorldPos(p::UIPixelPos, c::Camera)
    toWorldPos(toScreenPos(p, c), c)
end
toWorldPos(p::WorldPos, c::Camera) = p
function toUIPixelPos(p::ScreenPixelPos, c::Camera)
    scale = dpiScale()
    UIPixelPos(round(p.x/scale), round(p.y/scale))
end
function toUIPixelPos(p::WorldPos, c::Camera)
    toUIPixelPos(toScreenPos(p, c), c)
end
toUIPixelPos(p::UIPixelPos, c::Camera) = p
function toScreenPixelDims(dims::UIPixelDims,c::Camera)
    scale = dpiScale()
    ScreenPixelDims(round(scale*dims.w), round(scale*dims.h))
end
function toScreenPixelDims(dims::WorldDims,c::Camera)
    scale = worldScale(c)
    ScreenPixelDims(round(scale*dims.w), round(scale*dims.h))
end
toScreenPixelDims(dims::ScreenPixelDims,c::Camera) = dims
function toUIPixelDims(dims::ScreenPixelDims,c::Camera)
    scale = dpiScale()
    UIPixelDims(round(dims.w/scale), round(dims.h/scale))
end
function toUIPixelDims(d::WorldDims, c::Camera)
    toUIPixelDims(toScreenPixelDims(d, c), c)
end
toUIPixelDims(dims::UIPixelDims,c::Camera) = dims
function toWorldDims(dims::ScreenPixelDims,c::Camera)
    scale = worldScale(c)
    WorldDims(dims.w/scale, dims.h/scale)
end
function toWorldDims(d::UIPixelDims, c::Camera)
    toWorldDims(toScreenPixelDims(d, c), c)
end
toWorldDims(dims::WorldDims,c::Camera) = dims

SetRenderDrawColor(renderer::Ptr{SDL2.Renderer}, c::SDL2.Color) = SDL2.SetRenderDrawColor(
    renderer, Int64(c.r), Int64(c.g), Int64(c.b), Int64(c.a))

# Convenience functions to allow `WorldPos(x,y)...` to become `x,y`
Base.iterate(p::AbstractPos, i=1) = if i==1 return (p.x,2) elseif i==2 return (p.y,3) else nothing end
Base.iterate(p::AbstractDims, i=1) = if i==1 return (p.w,2) elseif i==2 return (p.h,3) else nothing end
# To allow .+ (but doesn't work)
#Base.length(::Union{AbstractPos,AbstractDims}) = 2

topLeftPos(center::P, dims::D) where P<:AbstractPos{Coord} where D<:AbstractDims{Coord} where Coord<:ScreenCoords = P(center.x - dims.w/2., center.y - dims.h/2.)  # positive is down
topLeftPos(center::P, dims::D) where P<:AbstractPos{Coord} where D<:AbstractDims{Coord} where Coord = P(center.x - dims.w/2., center.y + dims.h/2.)  # positive is up
rectOrigin(center::P, dims::D) where P<:AbstractPos{C} where D<:AbstractDims{C} where {C} = P(center.x - dims.w/2., center.y - dims.h/2.)  # always minus

#makeSDL2RectFromOrigin(p::ScreenPixelPos, d::ScreenPixelDims) = SDL2.Rect(p..., d...)
#makeSDL2RectFromCenter(p::ScreenPixelPos, d::ScreenPixelDims) = SDL2.Rect(rectOrigin(p,d)..., d...)
#makeSDL2RectFromOrigin(p,d) = makeSDL2RectFromCenter(toScreenPos(p), toScreenPixelDims(d))
#makeSDL2RectFromCenter(p,d) =
function renderRectCentered(cam, renderer, center::AbstractPos{C}, dims::AbstractDims{C}, color; outlineColor=nothing) where C
    origin = topLeftPos(center, dims)
    renderRectFromOrigin(cam, renderer, origin, dims, color; outlineColor=outlineColor)
end
function renderRectFromOrigin(cam, renderer, origin::AbstractPos{C}, dims::AbstractDims{C}, color; outlineColor=nothing) where C
    screenPos = toScreenPos(origin, cam)
    rect = SDL2.Rect(screenPos.x, screenPos.y, toScreenPixelDims(dims, cam)...)
    if color != nothing
        SetRenderDrawColor(renderer, color)
        SDL2.RenderFillRect(renderer, Ref(rect) )
    end
    if outlineColor != nothing
        SetRenderDrawColor(renderer, outlineColor)
        SDL2.RenderDrawRect(renderer, Ref(rect) )
    end
end

function blendAlphaColors(x::SDL2.Color, y::SDL2.Color)
    xAlphaPercent = x.a / 255
    yAlphaPercent = y.a / 255
    r = round(x.r*xAlphaPercent + (y.r - Int32(x.r) * xAlphaPercent) * yAlphaPercent)
    g = round(x.g*xAlphaPercent + (y.g - Int32(x.g) * xAlphaPercent) * yAlphaPercent)
    b = round(x.b*xAlphaPercent + (y.b - Int32(x.b) * xAlphaPercent) * yAlphaPercent)
    a = round(x.a + (1-xAlphaPercent)*yAlphaPercent * 255)
    SDL2.Color(r,g,b,a)
end

# pointwise subtraction with bounds checking (floors to 0)
-(a::SDL2.Color, b::Int) = SDL2.Color(a.r-min(b,a.r), a.g-min(b,a.g), a.b-min(b,a.b), a.a-min(b,a.a))
SDL2.Color(1,5,1,1) - 2 == SDL2.Color(0,3,0,0)


# ---- Text Rendering ----

fonts_cache = Dict()
txt_cache = Dict()
function sizeText(txt, fontName, fontSize)
    sizeText(txt, loadFont(dpiScale(), fontName, fontSize))
end
function sizeText(txt, font::Ptr{SDL2.TTF_Font})
   fw,fh = Cint[1], Cint[1]
   SDL2.TTF_SizeText(font, txt, pointer(fw), pointer(fh))
   return ScreenPixelDims(fw[1],fh[1])
end
function loadFont(scale, fontName, fontSize)
   fontSize = scale*fontSize
   fontKey = (fontName, Cint(round(fontSize)))
   if haskey(fonts_cache, fontKey)
       font = fonts_cache[fontKey]
   else
       font = SDL2.TTF_OpenFont(fontKey...)
       font == C_NULL && throw(ErrorException("Failed to load font '$fontKey'"))
       fonts_cache[fontKey] = font
   end
   return font
end
function createText(renderer, cam, txt, fontName, fontSize)
   font = loadFont(dpiScale(), fontName, fontSize)
   txtKey = (font, txt)
   if haskey(txt_cache, txtKey)
       tex = txt_cache[txtKey]
   else
       text = SDL2.TTF_RenderText_Blended(font, txt, SDL2.Color(20,20,20,255))
       tex = SDL2.CreateTextureFromSurface(renderer,text)
       #SDL2.FreeSurface(text)
       txt_cache[txtKey] = tex
   end

   fw,fh = Cint[1], Cint[1]
   SDL2.TTF_SizeText(font, txt, pointer(fw), pointer(fh))
   fw,fh = fw[1],fh[1]

   return tex, ScreenPixelDims(fw, fh)
end
@enum TextAlign centered leftJustified rightJustified
function renderText(renderer, cam::Camera, txt::String, pos::UIPixelPos
                    ; fontName = defaultFontName,
                     fontSize=defaultFontSize, align::TextAlign = centered)
   tex, fDims = createText(renderer, cam, txt, fontName, fontSize)
   renderTextSurface(renderer, cam, pos, tex, toUIPixelDims(fDims,cam), align)
end

function renderTextSurface(renderer, cam::Camera, pos::AbstractPos{C},
                           tex::Ptr{SDL2.Texture}, dims::AbstractDims{C}, align::TextAlign) where C
   screenPos = toScreenPos(pos, cam)
   screenDims = toScreenPixelDims(dims, cam)
   x,y, fw, fh = screenPos.x, screenPos.y, screenDims.w, screenDims.h
   renderPos = SDL2.Rect(0,0,0,0)
   if align == centered
       renderPos = SDL2.Rect(Int(floor(x-fw/2.)), Int(floor(y-fh/2.)), fw,fh)
   elseif align == leftJustified
       renderPos = SDL2.Rect(Int(floor(x)), Int(floor(y-fh/2.)), fw,fh)
   else # align == rightJustified
       renderPos = SDL2.Rect(Int(floor(x-fw)), Int(floor(y-fh/2.)), fw,fh)
   end
   SDL2.RenderCopy(renderer, tex, C_NULL, pointer_from_objref(renderPos))
   #SDL2.DestroyTexture(tex)
end

function hcat_render_text(lines, renderer, cam, gap, pos::UIPixelPos;
         fixedWidth=nothing, fontName=defaultFontName, fontSize=defaultFontSize)
    numLines = size(lines)[1]
    if fixedWidth != nothing
        widths = fill(fixedWidth,size(lines))
    else
        widths = [toUIPixelDims(sizeText(line, fontName, fontSize), cam).w for line in lines]
    end
    totalWidth = sum(widths) + gap*(numLines-1)
    runningWidth = 0
    leftMostPos = pos.x - totalWidth/2.0
    text_centers = []
    for i in 1:numLines
        linePos = leftMostPos + runningWidth
        leftPos = UIPixelPos(linePos, pos.y)
        renderText(renderer, cam, lines[i], leftPos; fontName=fontName, fontSize=fontSize, align=leftJustified)
        runningWidth += widths[i] + gap
        push!(text_centers, UIPixelPos(leftPos.x + widths[i]÷2, leftPos.y))
    end
    return text_centers
end

#  ------- Image rendering ---------

function render(t::Ptr{SDL2.Texture}, pos::AbstractPos{C}, cam::Camera, renderer; size::Union{Cvoid, AbstractDims{C}} = nothing) where C
    if (t == C_NULL) return end
    pos = toScreenPos(pos, cam)
    if size != nothing
        size = toScreenPixelDims(size, cam)
        w = size.w
        h = size.h
    else
        w,h,access = Cint[1], Cint[1], Cint[1]
        format = Cuint[1]
        SDL2.QueryTexture( t, format, access, w, h );
        w,h = w[], h[]
    end
    rect = SDL2.Rect(pos.x - w÷2,pos.y - h÷2,w,h)
    SDL2.RenderCopy(renderer, t, C_NULL, pointer_from_objref(rect))
end
