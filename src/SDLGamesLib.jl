module SDLGamesLib

using SimpleDirectMediaLayer
SDL2 = SimpleDirectMediaLayer

include("objects.jl")
include("display.jl")
include("timing.jl")
include("window.jl")
#include("pixel.jl")

end # module
