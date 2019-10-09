# -------- Opening a window ---------------
# Forward reference for @cfunction
function windowEventWatcher end
const window_event_watcher_cfunc = Ref(Ptr{Nothing}(0))

const window_paused = Threads.Atomic{UInt8}(0) # Whether or not the game should be running (if lost focus)
const frame_timer = WallTimer()


function makeWinRenderer(title = "My Julia SDL Game",
        min_win_dims::Union{Nothing,AbstractDims} = nothing)
    global winWidth, winHeight, winWidth_highDPI, winHeight_highDPI

    win = SDL2.CreateWindow(title,
        Int32(SDL2.WINDOWPOS_CENTERED()), Int32(SDL2.WINDOWPOS_CENTERED()), winWidth[], winHeight[],
        UInt32(SDL2.WINDOW_ALLOW_HIGHDPI|SDL2.WINDOW_OPENGL|SDL2.WINDOW_RESIZABLE|SDL2.WINDOW_SHOWN));
    if min_win_dims !== nothing
        SDL2.SetWindowMinimumSize(win, min_win_dims.w, min_win_dims.h)
    end
    window_event_watcher_cfunc[] = @cfunction(windowEventWatcher, Cint, (Ptr{Nothing}, Ptr{SDL2.Event}))
    SDL2.AddEventWatch(window_event_watcher_cfunc[], win);

    # Find out how big the created window actually was (depends on the system):
    winWidth[], winHeight[], winWidth_highDPI[], winHeight_highDPI[] = getWindowSize(win)
    #cam.w[], cam.h[] = winWidth_highDPI, winHeight_highDPI

    renderer = SDL2.CreateRenderer(win, Int32(-1), UInt32(SDL2.RENDERER_ACCELERATED | SDL2.RENDERER_PRESENTVSYNC))
    SDL2.SetRenderDrawBlendMode(renderer, UInt32(SDL2.BLENDMODE_BLEND))
    return win,renderer
end

# This huge function handles all window events. I believe it needs to be a
# callback instead of just the regular pollEvent because the main thread is
# paused while resizing, whereas this callback continues to trigger.
function windowEventWatcher(data_ptr::Ptr{Cvoid}, event_ptr::Ptr{SDL2.Event})::Cint
    global winWidth, winHeight, cam, window_paused, renderer, win
    ev = unsafe_load(event_ptr, 1)
    ee = ev._Event
    t = UInt32(ee[4]) << 24 | UInt32(ee[3]) << 16 | UInt32(ee[2]) << 8 | ee[1]
    t = SDL2.Event(t)
    if (t == SDL2.WindowEvent)
        event = unsafe_load( Ptr{SDL2.WindowEvent}(pointer_from_objref(ev)) )
        winevent = event.event;  # confusing, but that's what the field is called.
        if (winevent == SDL2.WINDOWEVENT_RESIZED || winevent == SDL2.WINDOWEVENT_SIZE_CHANGED)
            curPaused = window_paused[]
            window_paused[] = 1  # Stop game playing so resizing doesn't cause problems.
            winID = event.windowID
            eventWin = SDL2.GetWindowFromID(winID);
            if (eventWin == data_ptr)
                w,h,w_highDPI,h_highDPI = getWindowSize(eventWin)
                winWidth[], winHeight[] = w, h
                winWidth_highDPI[], winHeight_highDPI[] = w_highDPI, h_highDPI
                cam.w[], cam.h[] = winWidth[], winHeight[]
                recenterButtons!()
            end
            # Note: render after every resize event. I tried limiting it with a
            # timer, but it's hard to tune (too infrequent and the screen
            # blinks) & it didn't seem to reduce cpu significantly.
            render(sceneStack[end], renderer, eventWin)
            SDL2.GL_SwapWindow(eventWin);
            window_paused[] = curPaused  # Allow game to resume now that resizing is done.
        elseif (winevent == SDL2.WINDOWEVENT_FOCUS_LOST || winevent == SDL2.WINDOWEVENT_HIDDEN || winevent == SDL2.WINDOWEVENT_MINIMIZED)
            # Stop game playing so resizing doesn't cause problems.
            #if !debug  # For debug builds, allow editing while playing
                window_paused[] = 1
            #end
        elseif (winevent == SDL2.WINDOWEVENT_FOCUS_GAINED || winevent == SDL2.WINDOWEVENT_SHOWN)
            window_paused[] = 0
        end
        # Note that window events pause the game, so at the end of any window
        # event, restart the timer so it doesn't have a HUGE frame.
        start!(frame_timer)
    end
    return 0
end

function getWindowSize(win)
    w,h,w_highDPI,h_highDPI = Int32[0],Int32[0],Int32[0],Int32[0]
    SDL2.GetWindowSize(win, w, h)
    SDL2.GL_GetDrawableSize(win, w_highDPI, h_highDPI)
    return w[],h[],w_highDPI[],h_highDPI[]
end

# Having a QuitException is useful for testing, since an exception will simply
# pause the interpreter. For release builds, the catch() block will call quitSDL().
struct QuitException <: Exception end

function quitSDL(win)
    # Need to close the callback before quitting SDL to prevent it from hanging
    # https://github.com/n0name/2D_Engine/issues/3
    SDL2.DelEventWatch(window_event_watcher_cfunc[], win);
    SDL2.Mix_CloseAudio()
    SDL2.TTF_Quit()
    SDL2.Quit()
end
