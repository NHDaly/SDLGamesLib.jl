# Objects in the game and their supporting functions (update!, collide!, ...)

export AbstractPos, AbstractDims, WorldCoords, WorldPos, WorldDims, toWorldPos,
        toWorldDims, Vector2D, magSqrd, magnitude, unitVec

# Abstract positions and dimensions in arbitrary coordinate systems for the
# game. Concrete Pos and Dims must always be used with the same CoordType.
# Can convert between them (possibly in reference to the Camera).
abstract type AbstractPos{CoordType} end
abstract type AbstractDims{CoordType} end

""" WorldCoords are the absolute space of the game, independent of camera. """
struct WorldCoords end

"""
    WorldPos(5.0,-200.0)
x,y float coordinates in the game world (not necessarily the same as pixel
coordinates on the screen).
"""
struct WorldPos <: AbstractPos{WorldCoords}  # 0,0 == middle
    x::Float64
    y::Float64
end
toWorldPos(p::WorldPos, c) = p
"""
    WorldDims(5.0,-200.0)
w,h float dimensions in the game world (not necessarily the same as pixel
coordinates on the screen).
"""
struct WorldDims <: AbstractDims{WorldCoords}  # 0,0 == middle
    w::Float64
    h::Float64
end
toWorldDims(d::WorldDims, c) = d

"""
    Vector2D(-2.5,1.0)
x,y vector representing direction in the game world. Could represent a velocity,
a distance, etc. Subtracting two `WorldPos`itions results in a `Vector2D`.
"""
struct Vector2D   # TODO: consider making this abstract and parameterized on CoordType.
    x::Float64
    y::Float64
end
import Base.*, Base./, Base.-, Base.+
+(a::Vector2D, b::Vector2D) = Vector2D(a.x+b.x, a.y+b.y)
-(a::Vector2D, b::Vector2D) = Vector2D(a.x-b.x, a.y-b.y)
*(a::Vector2D, x::Number) = Vector2D(a.x*x, a.y*x)
*(x::Number, a::Vector2D) = a*x
/(a::Vector2D, x::Number) = Vector2D(a.x/x, a.y/x)
+(a::P, b::Vector2D) where {P<:AbstractPos} = P(a.x+b.x, a.y+b.y)
-(a::P, b::Vector2D) where {P<:AbstractPos} = P(a.x-b.x, a.y-b.y)
+(a::Vector2D, b::P) where {P<:AbstractPos} = P(a.x+b.x, a.y+b.y)
-(a::Vector2D, b::P) where {P<:AbstractPos} = P(a.x-b.x, a.y-b.y)
-(a::AbstractPos, b::AbstractPos) = Vector2D(a.x-b.x, a.y-b.y)
-(x::AbstractPos) = AbstractPos(-x.x, -x.y)
-(x::Vector2D) = Vector2D(-x.x, -x.y)

magSqrd(v::Vector2D) = v.x^2 + v.y^2
magnitude(v::Vector2D) = sqrt(magSqrd(v))
unitVec(v::Vector2D) = v / magnitude(v)
