package main

import easing "core:math/ease"

easing :: easing

Transformable :: struct
{
    xalign: f32,
    yalign: f32,

    xscale: f32,
    yscale: f32,

    angle:  f32,

    using position: [3]f32,
}

Transform :: struct
{
    using transformable: Transformable,

    ease: easing.Ease,
    time: f32,
    loop: bool,

    tween: struct
    {
        tweener: ^easing.Flux_Tween(f32),
        time_stamp: f32,
        finished: bool,
        uniforms: Shader_Uniforms,
        using transformable: Transformable,
    }
}

transform_tweeners: easing.Flux_Map(f32)
transform_shader:   Shader
transform_uniforms: Shader_Uniforms

transform_values :: proc(t: ^Transform)
{
    if t.tween.tweener == nil && t.tween.finished == false
    {
        t.tween.tweener = easing.flux_to(
            &transform_tweeners,
            &t.tween.time_stamp,
            1.0,
            t.ease,
            time.Duration(f32(time.Second) * t.time))

        t.tween.tweener.data = t
        t.tween.tweener.on_start = proc(m: ^easing.Flux_Map(f32), data: rawptr)
        {
            trans := cast(^Transform)data
            if trans == nil do return

            trans.tween.uniforms = make(Shader_Uniforms, allocator = context.temp_allocator)

            for k, v in transform_uniforms
            {
                trans.tween.uniforms[k] = {} // TODO: Resetar esse valor usando o tipo do any
            }

            fmt.println(trans.tween.uniforms)
        }
        t.tween.tweener.on_update = proc(m: ^easing.Flux_Map(f32), data: rawptr)
        {
            trans := cast(^Transform)data
            if trans == nil do return

            trans.tween.xalign = math.lerp(trans.tween.xalign, trans.xalign, trans.tween.time_stamp)
            trans.tween.yalign = math.lerp(trans.tween.yalign, trans.yalign, trans.tween.time_stamp)

            trans.tween.xscale = math.lerp(trans.tween.xscale, trans.xscale, trans.tween.time_stamp)
            trans.tween.yscale = math.lerp(trans.tween.yscale, trans.yscale, trans.tween.time_stamp)

            trans.tween.angle = math.lerp(trans.tween.angle, trans.angle, trans.tween.time_stamp)

            trans.tween.x = math.lerp(trans.tween.x, trans.x, trans.tween.time_stamp)
            trans.tween.y = math.lerp(trans.tween.y, trans.y, trans.tween.time_stamp)
            trans.tween.z = math.lerp(trans.tween.z, trans.z, trans.tween.time_stamp)

            if trans.tween.uniforms != nil
            {
                for k, v in transform_uniforms
                {
                    if k in trans.tween.uniforms
                    {
                        switch &_v in &trans.tween.uniforms[k]
                        {
                        case f32:
                            _v = math.lerp(_v, v.(f32), trans.tween.time_stamp)

                        case i32:
                            _v = i32(math.lerp(f32(_v), f32(v.(i32)), trans.tween.time_stamp))

                        case [2]f32:
                            _v.x = math.lerp(_v.x, v.([2]f32).x, trans.tween.time_stamp)
                            _v.y = math.lerp(_v.y, v.([2]f32).y, trans.tween.time_stamp)

                        case [3]f32:
                            _v.x = math.lerp(_v.x, v.([3]f32).x, trans.tween.time_stamp)
                            _v.y = math.lerp(_v.y, v.([3]f32).y, trans.tween.time_stamp)
                            _v.z = math.lerp(_v.z, v.([3]f32).z, trans.tween.time_stamp)

                        case [4]f32:
                            _v.x = math.lerp(_v.x, v.([4]f32).x, trans.tween.time_stamp)
                            _v.y = math.lerp(_v.y, v.([4]f32).y, trans.tween.time_stamp)
                            _v.z = math.lerp(_v.z, v.([4]f32).z, trans.tween.time_stamp)
                            _v.w = math.lerp(_v.w, v.([4]f32).w, trans.tween.time_stamp)
                            fmt.println(_v)

                        case [2]i32:
                            _v.x = i32(math.lerp(
                                    f32(_v.x), f32(v.([2]i32).x), trans.tween.time_stamp))
                            _v.y = i32(math.lerp(
                                    f32(_v.y), f32(v.([2]i32).y), trans.tween.time_stamp))
                        case [3]i32:
                            _v.x = i32(math.lerp(
                                    f32(_v.x), f32(v.([3]i32).x), trans.tween.time_stamp))
                            _v.y = i32(math.lerp(
                                    f32(_v.y), f32(v.([3]i32).y), trans.tween.time_stamp))
                            _v.z = i32(math.lerp(
                                    f32(_v.z), f32(v.([3]i32).z), trans.tween.time_stamp))
                        case [4]i32:
                            _v.x = i32(math.lerp(
                                    f32(_v.x), f32(v.([4]i32).x), trans.tween.time_stamp))
                            _v.y = i32(math.lerp(
                                    f32(_v.y), f32(v.([4]i32).y), trans.tween.time_stamp))
                            _v.z = i32(math.lerp(
                                    f32(_v.z), f32(v.([4]i32).z), trans.tween.time_stamp))
                            _v.w = i32(math.lerp(
                                    f32(_v.w), f32(v.([4]i32).w), trans.tween.time_stamp))
                        }
                    }
                }
            }
        }
        t.tween.tweener.on_complete = proc(m: ^easing.Flux_Map(f32), data: rawptr)
        {
            trans := cast(^Transform)data
            if trans == nil do return

            trans.tween.tweener = nil
            delete(trans.tween.uniforms)

            if !trans.loop
            {
                trans.tween.finished = true
            }
            else
            {
                trans.tween = {}
                trans.tween.time_stamp = 0
            }
        }
    }
}

preload_transformations :: proc()
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

        uniform sampler2D Textures[4];
        uniform vec4 modulate;

        in vec4 vColor;
        in vec2 vTexCoord;
    
        out vec4 fragColor;

        void main() {
            vec4 color = texture(Textures[0], vTexCoord * vec2(1, -1));
            fragColor = modulate; //color * vColor;
        }
        `

    transform_shader = compile_shader(SHADER_VS, SHADER_FS)
    transform_uniforms = make(Shader_Uniforms)
}

delete_transformations :: proc()
{
    delete(transform_uniforms)
    gl.DeleteProgram(transform_shader.id)
}
