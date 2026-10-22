package main

import "vendor:OpenGL"
import "core:math/linalg"
import "core:math"
import "core:image/png"
import "core:strings"

gl :: OpenGL
linalg :: linalg
math :: math
png :: png
strings :: strings

GL_MAX :: 3
GL_MIN :: 1

IMMEDIATE_MAX_VERTEX :: 33
IMMEDIATE_MAX_TEXTURES :: 44

immediate_buffer: u32
immediate_vertex_array: u32
immediate_data: [dynamic; IMMEDIATE_MAX_VERTEX]Vertex
immediate_shader: Shader
immediate_uniforms: Shader_Uniforms
immediate_textures: []Texture
immediate_textures_units: [dynamic; IMMEDIATE_MAX_TEXTURES]i32

viewport_projection: matrix[4, 4]f32
viewport_camera: matrix[4, 4]f32

default_texture: Texture

preload_gl :: proc()
{
    gl.GenBuffers(1, &immediate_buffer)
    gl.BindBuffer(gl.ARRAY_BUFFER, immediate_buffer)
    gl.BufferData(
        gl.ARRAY_BUFFER,
        IMMEDIATE_MAX_VERTEX * size_of(Vertex),
        nil,
        gl.DYNAMIC_DRAW)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    gl.GenVertexArrays(1, &immediate_vertex_array)
    gl.BindVertexArray(immediate_vertex_array)
    gl.BindBuffer(gl.ARRAY_BUFFER, immediate_buffer)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE,
        i32(size_of(Vertex)),
        uintptr(0))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(
        1,
        4,
        gl.FLOAT,
        gl.TRUE,
        i32(size_of(Vertex)),
        3 * size_of(f32))
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(
        2,
        2,
        gl.FLOAT,
        gl.TRUE,
        i32(size_of(Vertex)),
        7 * size_of(f32))
    gl.BindVertexArray(0)

    {
        fullpath := os.join_path({directory, "test.png"}, context.allocator) or_else "test.png"
        defer delete(fullpath)

        image: ^png.Image
        image_error: png.Error
        if image, image_error = png.load_from_file(fullpath, { .alpha_add_if_missing  }); image_error == nil
        {
            defer png.destroy(image)
            default_texture = load_texture(raw_data(image.pixels.buf), { i32(image.width), i32(image.height) })
        }
    }
}

load_texture :: proc(data: rawptr, size: [2]i32, filter: Texture_Filter = .Linear, channels: Texture_Channels = .RGBA) -> (texture: Texture)
{
    filter_non_mipmap : i32
    filter_mipmap : i32

    switch filter
    {
    case .Linear:
        filter_non_mipmap = gl.LINEAR
        filter_mipmap = gl.LINEAR_MIPMAP_LINEAR

    case .Nearest:
        filter_non_mipmap = gl.NEAREST
        filter_mipmap = gl.NEAREST_MIPMAP_NEAREST
    }

    channels_type: i32
    switch channels
    {
    case .RED: channels_type = gl.RED
    case .RGB: channels_type = gl.RGB
    case .RGBA: channels_type = gl.RGBA
    }

    gl.GenTextures(1, &texture.id)
    gl.BindTexture(gl.TEXTURE_2D, texture.id)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter_mipmap)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter_non_mipmap)
    gl.TexImage2D(gl.TEXTURE_2D, 0, channels_type, size.x, size.y, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
    gl.GenerateMipmap(gl.TEXTURE_2D)
    gl.BindTexture(gl.TEXTURE_2D, 0)
    return
}

compile_shader :: proc(vs: string, fs: string) -> (sh: Shader)
{
    vss := compile_one(vs, .VERTEX_SHADER)
    fss := compile_one(fs, .FRAGMENT_SHADER)

    compile_one :: proc(s: string, t: gl.Shader_Type) -> u32
    {
        sh, ok := gl.compile_shader_from_source(s, t)
        e: Error

        if !ok
        {
            msg, type  := gl.get_last_error_message()

            gl.DeleteShader(sh)

            e = Generic_Error {
                code = -1,
                message = msg,
            }
        }

        handle_error(e)

        return sh
    }

    sh.id = gl.CreateProgram()

    gl.AttachShader(sh.id, vss)
    gl.AttachShader(sh.id, fss)
    gl.LinkProgram(sh.id)

    gl.DeleteShader(vss)
    gl.DeleteShader(fss)

    return
}

delete_gl :: proc()
{
    
    gl.DeleteTextures(1, &default_texture.id)
    gl.DeleteBuffers(1, &immediate_buffer)
    gl.DeleteVertexArrays(1, &immediate_vertex_array)
}

Clear_Values :: struct
{
    color: [4]f32,
    depth:    f64,
    stencil:  i32,
}

render_target_begin :: proc(clear_values: Clear_Values)
{
    COLOR   :: gl.COLOR_BUFFER_BIT
    DEPTH   :: gl.DEPTH_BUFFER_BIT
    STENCIL :: gl.STENCIL_BUFFER_BIT

    gl.Clear(COLOR | DEPTH | STENCIL)
    gl.ClearColor(**clear_values.color)
    gl.ClearDepth(clear_values.depth)
    gl.ClearStencil(clear_values.stencil)
}

Viewport_Mode :: struct
{
    size:      f32,
    offset: [3]f32,
    angles: [3]f32,

    width:  i32,
    height: i32,
}

viewport_begin :: proc(mode: Viewport_Mode)
{
    gl.Viewport(0, 0, mode.width, mode.height)

    half_size := ([2]f32 {
        f32(mode.width) / mode.size,
        f32(mode.height) / mode.size,
    } / 2)

    viewport_projection = linalg.matrix_ortho3d(
        -half_size.x,
        +half_size.x,
        -half_size.y,
        +half_size.y,
        -100,
        +100)

    rotation := linalg.matrix4_from_euler_angles_yxz_f32(
        math.to_radians(mode.angles.y),
        math.to_radians(mode.angles.x),
        math.to_radians(mode.angles.z))

    forward := [4]f32 { 0, 0, -1, 0 }
    right   := [4]f32 { 1, 0,  0, 0 }
    up      := [4]f32 { 0, 1,  0, 0 }

    f4 := forward * rotation
    r4 := right * rotation
    u4 := up * rotation

    viewport_camera = linalg.matrix4_look_at_from_fru_f32(
        mode.offset,
        f4.xyz,
        r4.xyz,
        u4.xyz)
}

Vertex :: struct
{
    position: [3]f32,
    color:    [4]f32,
    texcoord: [2]f32,
}

primitive_begin :: proc()
{
    clear(&immediate_data)
    clear(&immediate_textures_units)

    immediate_uniforms = nil
    immediate_shader = {}
    immediate_textures = nil
}

primitive_vertex :: proc(v: Vertex)
{
    append(&immediate_data, v)
}

primitive_end :: proc()
{
    gl.BindBuffer(gl.ARRAY_BUFFER, immediate_buffer)
    gl.BufferSubData(
        gl.ARRAY_BUFFER,
        0,
        len(immediate_data) * size_of(Vertex),
        &immediate_data)

    if gl.IsProgram(immediate_shader.id)
    {
        gl.UseProgram(immediate_shader.id)

        {
            projection_location := gl.GetUniformLocation(
                                     immediate_shader.id, "Projection")

            gl.UniformMatrix4fv(
                projection_location,
                1,
                gl.FALSE,
                raw_data(&viewport_projection))

            camera_location := gl.GetUniformLocation(
                                     immediate_shader.id, "Camera")

            gl.UniformMatrix4fv(
                camera_location,
                1,
                gl.FALSE,
                raw_data(&viewport_camera))

            if len(immediate_textures_units) > 0
            {
                textures_location := gl.GetUniformLocation(
                                       immediate_shader.id, "Textures")

                gl.Uniform1iv(
                    textures_location,
                    i32(len(immediate_textures_units)),
                    &immediate_textures_units[0])
            }
        }

        for k, v in immediate_uniforms
        {
            loc := gl.GetUniformLocation(
                     immediate_shader.id, strings.unsafe_string_to_cstring(k))

            switch _v in v
            {
            case f32: gl.Uniform1f(loc, _v)
            case i32: gl.Uniform1i(loc, _v)

            case [2]f32: gl.Uniform2f(loc, _v.x, _v.y)
            case [3]f32: gl.Uniform3f(loc, _v.x, _v.y, _v.z)
            case [4]f32: gl.Uniform4f(loc, _v.x, _v.y, _v.z, _v.w)

            case [2]i32: gl.Uniform2i(loc, _v.x, _v.y)
            case [3]i32: gl.Uniform3i(loc, _v.x, _v.y, _v.z)
            case [4]i32: gl.Uniform4i(loc, _v.x, _v.y, _v.z, _v.w)
            }
        }
    }

    gl.BindVertexArray(immediate_vertex_array)
    gl.DrawArrays(gl.QUADS, 0, cast(i32)len(immediate_data))
    gl.UseProgram(0)
    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    for i in 0..<len(immediate_textures_units)
    {
        gl.ActiveTexture(gl.TEXTURE0 + u32(immediate_textures_units[i]))
        gl.BindTexture(gl.TEXTURE_2D, 0)
    }
}

Shader :: struct
{
    id: u32,
}

Shader_Uniforms :: map[string]any

primitive_shader :: proc(shader: Shader, uniforms: Shader_Uniforms)
{
    immediate_shader = shader
    immediate_uniforms = uniforms
}

Texture_Filter :: enum
{
    Linear,
    Nearest,
}

Texture_Channels :: enum
{
    RED,
    RGB,
    RGBA,
}

Texture :: struct
{
    id: u32,
}

primitive_textures :: proc(t: []Texture)
{
    clear(&immediate_textures_units)

    miss: int
    for i in 0..<len(t)
    {
        if !gl.IsTexture(t[i].id)
        {
            miss += 1
            continue
        }
        unit := i - miss
        gl.ActiveTexture(gl.TEXTURE0 + u32(unit))
        gl.BindTexture(gl.TEXTURE_2D, t[i].id)
        append(&immediate_textures_units, i32(unit))
    }

    immediate_textures = t
}
