package main

import "vendor:OpenGL"
import "core:math/linalg"
import "core:math"

gl :: OpenGL
linalg :: linalg
math :: math

GL_MAX :: 3
GL_MIN :: 1

IMMEDIATE_MAX_VERTEX :: 33

immediate_buffer: u32
immediate_vertex_array: u32
immediate_data: [dynamic; IMMEDIATE_MAX_VERTEX]Vertex
immediate_shader: Shader
immediate_uniforms: Shader_Uniforms

viewport_projection: matrix[4, 4]f32
viewport_camera: matrix[4, 4]f32

transform_shader: Shader
transform_uniforms: Shader_Uniforms

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
    gl.VertexAttribPointer(
        2,
        2,
        gl.FLOAT,
        gl.TRUE,
        i32(size_of(Vertex)),
        7 * size_of(f32))
    gl.BindVertexArray(0)

    {
        SHADER_VS ::
        `
        #version 310 es

        in vec3 aPosition;
        in vec4 aColor;
        in vec2 aTexCoord;

        uniform mat4 Projection;
        uniform mat4 Camera;

        out vec4 vColor;
        out vec2 vTexCoord;

        void main() {
            gl_Position = Projection * Camera * vec4(aPosition, 1.0);

            vColor = aColor;
            vTexCoord = aTexCoord;
        }
        `

        SHADER_FS ::
        `
        #version 310 es

        precision mediump float;

        in vec4 vColor;
        in vec2 vTexCoord;
    
        out vec4 fragColor;

        void main() {
            fragColor = vColor;
        }
        `

        transform_shader = compile_shader(SHADER_VS, SHADER_FS)
    }

    transform_uniforms = make(Shader_Uniforms)
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
    delete(transform_uniforms)
    gl.DeleteProgram(transform_shader.id)
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
        f32(mode.width),
        f32(mode.height),
    } / 2) / mode.size

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
        }

        // TODO: Set ShaderUniforms uniforms here
    }

    gl.BindVertexArray(immediate_vertex_array)
    gl.DrawArrays(gl.QUADS, 0, cast(i32)len(immediate_data))
    gl.UseProgram(0)
    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
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
