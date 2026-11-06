shader_type spatial;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float zone = (1.0-smoothstep(26.0,32.0,world.x))*smoothstep(10.0,16.0,world.z);
    float ripple = sin(world.x*5.0+sin(world.z*.6)*2.0);
    float dunes = sin(world.x*.36+world.z*.21);
    float wave = sin(world.x*7.0 + world.z*2.0 + sin(world.z*.7)*1.5);
    float fine = sin(world.x*39.0)*sin(world.z*31.0);
    float detail = mix(ripple*.045, dunes*.025 + wave*.035 + fine*.008,zone);
    ALBEDO = vec3(.76,.55,.32)*(1.0+detail);
    ROUGHNESS = .96;
}
