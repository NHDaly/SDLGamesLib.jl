
function pollEvent!()
    #SDL2.Event() = [SDL2.Event(NTuple{56, Uint8}(zeros(56,1)))]
    SDL_Event() = Array{UInt8}(zeros(56))
    e = SDL_Event()
    success = (SDL2.PollEvent(e) != 0)
    return e,success
end
function getEventType(e::Array{UInt8})
    # HAHA This is still pretty janky, but I guess that's all you can do w/ unions.
    bitcat(UInt32, e[4:-1:1])
end
function getEventType(e::SDL2.Event)
    bitcat(UInt32, e[4:-1:1])
end

function bitcat(::Type{T}, arr)::T where T<:Number
    out = zero(T)
    for x in arr
        out = out << T(sizeof(x)*8)
        out |= convert(T, x)  # the `convert` prevents signed T from promoting to Int64.
    end
    out
end
