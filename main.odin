package main

import "core:time"
import "core:fmt"

exit:   bool = false
target: f64  = 60

import "vendor:sdl3"

window:     ^sdl3.Window
event:       sdl3.Event
gl_context: ^sdl3.GLContextState

Service_Type :: enum
{
    Video,
    Events,
    Audio,
    Joystick,
    Gamepad,
}

create :: proc()
{
    error: Error = nil

    if !sdl3.Init(sdl3.INIT_VIDEO)    do push_service_error(&error, {.Video})
    if !sdl3.Init(sdl3.INIT_EVENTS)   do push_service_error(&error, {.Events})
    if !sdl3.Init(sdl3.INIT_AUDIO)    do push_service_error(&error, {.Audio})
    if !sdl3.Init(sdl3.INIT_JOYSTICK) do push_service_error(&error, {.Joystick})
    if !sdl3.Init(sdl3.INIT_GAMEPAD)  do push_service_error(&error, {.Gamepad})

    handle_error(error)

    flags: sdl3.WindowFlags
    flags += { .OPENGL }

    title :: ODIN_BUILD_PROJECT_NAME

    profile_mask: sdl3.GLProfileFlag = .ES

    sdl3.GL_SetAttribute(sdl3.GL_CONTEXT_MAJOR_VERSION, GL_MAX)
    sdl3.GL_SetAttribute(sdl3.GL_CONTEXT_MINOR_VERSION, GL_MIN)
    sdl3.GL_SetAttribute(sdl3.GL_CONTEXT_PROFILE_MASK, i32(profile_mask))

    if window = sdl3.CreateWindow(title, 1024, 600, flags); window == nil
    {
        error = Generic_Error { string(sdl3.GetError()), -1 }
    }

    handle_error(error)

    gl_context = sdl3.GL_CreateContext(window)
    gl.load_up_to(3, 1, gl_proc_address)

    preload_gl()

    when #defined(screen_create) do screen_create()
}

events :: proc()
{
    for sdl3.PollEvent(&event)
    {
        #partial switch event.type
        {
        case .QUIT: exit = true
        }
    }
}

update :: proc(delta: f64)
{
    when #defined(screen_update) do screen_update(delta)
}

render :: proc(alpha: f64)
{
    render_target_begin({})
    viewport_begin({ 25.0, {0, 0, 0}, { 0, 0, 0 }, 1024, 600})
    primitive_begin()
    primitive_shader(transform_shader, transform_uniforms)
    primitive_vertex({ {0, 0, 0}, {1, 0, 0, 1}, {} })
    primitive_vertex({ {1, 0, 0}, {1, 1, 0, 1}, {} })
    primitive_vertex({ {1, 1, 0}, {1, 1, 1, 1}, {} })
    primitive_vertex({ {0, 1, 0}, {0, 1, 1, 1}, {} })
    primitive_end()

    when #defined(screen_render) do screen_render(alpha)

    sdl3.GL_SwapWindow(window)
}

close :: proc()
{
    when #defined(screen_close) do screen_close()

    delete_gl()
    sdl3.GL_DestroyContext(gl_context)
    sdl3.DestroyWindow(window)
    sdl3.Quit()
}

main :: proc()
{
    accm: f64
    ups: f64

    previous := time.tick_now()

    create()

    for !exit
    {
        ups = 1.0 / target

        delta := f64(time.duration_seconds(time.tick_lap_time(&previous)))
        accm += delta

        events()

        for accm >= ups
        {
            update(ups)
            accm -= ups
        }

        alpha := accm / ups

        render(alpha)
    }

    close()
}
