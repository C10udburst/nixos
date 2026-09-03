#extension GL_OES_standard_derivatives : enable
#extension GL_EXT_shader_texture_lod : enable

precision highp float;

// ---------------------------------------------------------------------
// Endless seamless non-repeating texture synthesis adapted for driftwm.
// Based on HPG'18 "High-Performance By-Example Noise using a Histogram-Preserving Blending Operator"
// ---------------------------------------------------------------------

#define SHOW_GRID 0 // Option to show hexagonal patch grid (1 = enabled, 0 = disabled)
#define CON 0       // Contrast-preserving interpolation
#define Z   8.0     // Patch scale inside example texture

varying vec2 v_coords;
uniform sampler2D tex;

uniform vec2 u_camera;
uniform float u_zoom;
uniform vec2 u_output_size;
uniform vec2 u_texture_size;

#ifdef GL_EXT_shader_texture_lod
#define sampleTexGrad(sampler, uv, ddx, ddy) texture2DGradEXT(sampler, uv, ddx, ddy)
#else
#define sampleTexGrad(sampler, uv, ddx, ddy) texture2D(sampler, uv)
#endif

// Safe hash that avoids float precision breakdown on large or negative coordinates
vec2 hash2(vec2 p) {
    p = mod(mod(p, 1024.0) + 1024.0, 1024.0);
    vec2 d = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(d) * 43758.5453);
}

#define srgb2rgb(V) pow(max(V, 0.0), vec4(2.2))
#define rgb2srgb(V) pow(max(V, 0.0), vec4(1.0 / 2.2))

vec4 samplePatch(vec2 I, vec2 U, vec2 Gx, vec2 Gy, vec4 m, vec2 tex_aspect) {
    vec2 uv = U / Z - hash2(I);
    uv.x /= tex_aspect.x;
    // Safe fract: prevents clamp-to-edge stretching for negative and large coordinates
    uv = uv - floor(uv);
    return srgb2rgb(sampleTexGrad(tex, uv, Gx, Gy)) - m * float(CON);
}

void main() {
    // M is the exact inverse of mat2(1.0, 0.0, 0.5, sqrt(3.0) / 2.0)
    mat2 M = mat2(1.0, 0.0, -1.0 / sqrt(3.0), 2.0 / sqrt(3.0));

    // Screen pixel position -> canvas coordinates (in canvas pixels)
    vec2 canvas = v_coords * u_output_size + u_camera;

    // Isotropic scaling scalar: ensures equilateral triangles / regular hexagons without stretching
    vec2 screen_size = u_output_size * u_zoom;
    float scale = (u_texture_size.y > 0.0) ? u_texture_size.y : screen_size.y;
    vec2 tex_aspect = (u_texture_size.x > 0.0 && u_texture_size.y > 0.0)
        ? vec2(u_texture_size.x / u_texture_size.y, 1.0)
        : vec2(1.0);

    // World coordinate space for hexagonal lattice
    vec2 U = (canvas / scale) * Z;

    vec2 V = M * U;                                    // Tilted space coordinates
    vec2 I = floor(V);                                 // Hex-tile id
    vec2 F_xy = V - I;                                 // Fractional local coordinates in [0, 1)
    vec3 F = vec3(F_xy, 1.0 - F_xy.x - F_xy.y);

    vec2 Gx = dFdx(U / Z) / tex_aspect;
    vec2 Gy = dFdy(U / Z) / tex_aspect;
    vec4 m = srgb2rgb(texture2D(tex, vec2(0.5), 99.0)); // Mean texture color

    vec3 W;
    vec4 O;

    if (F.z > 0.0) {
        W = vec3(F.z, F.y, F.x);
        O = W.x * samplePatch(I, U, Gx, Gy, m, tex_aspect)
          + W.y * samplePatch(I + vec2(0.0, 1.0), U, Gx, Gy, m, tex_aspect)
          + W.z * samplePatch(I + vec2(1.0, 0.0), U, Gx, Gy, m, tex_aspect);
    } else {
        W = vec3(-F.z, 1.0 - F.y, 1.0 - F.x);
        O = W.x * samplePatch(I + vec2(1.0, 1.0), U, Gx, Gy, m, tex_aspect)
          + W.y * samplePatch(I + vec2(1.0, 0.0), U, Gx, Gy, m, tex_aspect)
          + W.z * samplePatch(I + vec2(0.0, 1.0), U, Gx, Gy, m, tex_aspect);
    }

    #if CON
    O = m + O / length(W);                             // Contrast preserving interpolation
    #endif

    O = clamp(rgb2srgb(O), 0.0, 1.0);
    if (m.g == 0.0) {
        O = O.rrrr;                                    // Handles B&W textures
    }

    #if SHOW_GRID
    float p = 0.7 * abs(dFdy(U.y));
    float grid_val = min(W.x, min(W.y, W.z));
    float grid_line = smoothstep(p, -p, grid_val - p);
    O = mix(O, vec4(1.0, 1.0, 1.0, 1.0), grid_line);
    #endif

    gl_FragColor = vec4(O.rgb, 1.0);
}
