primitive type Pixel   <: Signed   64 end
# A constructor to create values of the type MyInt8.
Pixel(n::Int64) = reinterpret(Pixel, n)
_value(p::Pixel) = reinterpret(Int64, p)
valuetype(p::Pixel) = Int64
valuetype(p::Type{Pixel}) = Int64

# Global for multiplying
px = Pixel(1)

# This allows the REPL to show values of type MyInt8.
Base.show(io :: IO, x :: Pixel) = print(io, "$(_value(x))px")

# Pixel × Pixel => Pixel
for (op) in (:+, :-, :rem, :mod, :div, :fld, :cld)
    @eval begin
        import Base.($op)
        function ($op)(x::Pixel, y::Pixel)
            Pixel((valuetype(Pixel))(($op)(_value(x),_value(y))))
        end
    end
end

# Pixel × ... => Pixel
# TODO: How do i feel about float-to-pixel conversion? Currently throws InexactError.
# Relies on float->Pixel conversion
for op in (:*, :^, :/)
    @eval begin
        import Base.($op)
        function ($op)(x::Pixel, y::Number)
            Pixel((valuetype(Pixel))(($op)(_value(x),y)))
        end
    end
end

# ... × Pixel => Pixel
for op in (:*,)
    @eval begin
        import Base.($op)
        function ($op)(x::Number, y::Pixel)
            Pixel((valuetype(Pixel))(($op)(x,_value(y))))
        end
    end
end

# Pixel => Pixel
for op in (:zero, :one,)
    @eval begin
        import Base.($op)
        function ($op)(x::Pixel)
            Pixel((valuetype(Pixel))(($op)(_value(x))))
        end
    end
end

# Pixel × Pixel => ...
for op in (:(==), :!=, :>, :<, :(<=), :(>=), :cmp)
    @eval begin
        import Base.($op)
        function ($op)(x::Pixel, y::Pixel)
            ($op)(_value(x),_value(y))
        end
    end
end

# Pixel => ...
for op in (:sign, :signbit, :isinteger)
    @eval begin
        import Base.($op)
        function ($op)(x::Pixel)
            ($op)(_value(x))
        end
    end
end


import Base: read,write
function read(s::IO, ::Type{Pixel})
    r = read(s,valuetype(Pixel))
    Pixel(r)
end
function write(s::IO, p::Pixel)
    write(s, _value(p))
end


import Base: typemin, typemax
typemin(::Type{Pixel}) = typemin(valuetype(Pixel))
typemax(::Type{Pixel}) = typemax(valuetype(Pixel))

#import Base: convert, promote_rule
## TODO: Does conversion make sense? Probably not, right?
#convert(::Type{Pixel}, x::Pixel) = x
#convert(::Type{Pixel}, x::Integer) = Pixel(convert(valuetype(Pixel),x))
#
##convert(::Type{Integer}, x::Pixel) = (isinteger(x) ? convert(Integer, x.num) : throw(InexactError()))
##convert(::Type{T}, x::Pixel) where {T<:Integer} = (isinteger(x) ? convert(T, x.num) : throw(InexactError()))
#
##convert(::Type{AbstractFloat}, x::Pixel) = float(x.num)/float(x.den)
#convert(::Type{Pixel}, x::Float64) = convert(Pixel, valuetype(Pixel)(x))
#convert(::Type{Pixel}, x::Float32) = convert(Pixel, valuetype(Pixel)(x))
#
## TODO: I don't think promotion makes sense actually..
#promote_rule(::Type{Pixel}, ::Type{S}) where {S<:Integer} = Pixel
#promote_rule(::Type{Pixel}, ::Type{Pixel}) where {S<:Integer} = Pixel
#promote_rule(::Type{Pixel}, ::Type{S}) where {S<:AbstractFloat} = Pixel
