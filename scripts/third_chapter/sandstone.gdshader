shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    // Local art-standard strip; the rest of the chapter keeps its approved palette.
    float zone = (1.0-smoothstep(26.0,32.0,world.x))*smoothstep(10.0,16.0,world.z);
    float strata = sin(world.y*5.0 + sin(world.x*.32+world.z*.19)*.55);
    float grain = sin(world.x*29.0+world.z*19.0)*sin(world.y*23.0+world.z*11.0);
    float seam = smoothstep(.90,.99,sin(world.y*2.4+sin(world.x*.21+world.z*.18)*.4));
    vec3 tint = COLOR.rgb * (1.0 + zone*(strata*.045 + grain*.012 - seam*.065));
    ALBEDO = tint;
    ROUGHNESS = .94;
}
