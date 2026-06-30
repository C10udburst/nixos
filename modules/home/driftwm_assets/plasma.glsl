// Plasma veins — recursive cosine distortion
precision highp float;

varying vec2 v_coords;
uniform vec2 size;
uniform vec2 u_camera;

void main() {
    vec2 pixel = v_coords * size + u_camera;
    vec2 uv = (2.0 * pixel - size) / min(size.x, size.y);

    for (int k = 1; k < 10; k++) {
        float i = float(k);
        uv.x += 0.6 / i * cos(i * 2.5 * uv.y);
        uv.y += 0.6 / i * cos(i * 1.5 * uv.x);
    }

    float vein = 0.1 / max(abs(sin(-uv.y - uv.x)), 0.005);
    float foam = smoothstep(0.08, 0.40, vein);

    vec3 dark = vec3(0.118, 0.118, 0.180);  // #1e1e2e base
    vec3 mid  = vec3(0.094, 0.094, 0.145);  // #181825 mantle
    vec3 foam_color = vec3(0.796, 0.651, 0.969);  // #cba6f7 mauve

    vec3 col = mix(mix(dark, mid, foam * 0.3), foam_color, foam);

    gl_FragColor = vec4(col, 1.0);
}
