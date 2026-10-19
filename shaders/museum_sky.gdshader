shader_type sky;

uniform vec4 zenith : source_color = vec4(0.14,0.23,0.45,1.0);
uniform vec4 horizon : source_color = vec4(0.9,0.55,0.65,1.0);
uniform vec4 ground_color : source_color = vec4(0.16,0.18,0.24,1.0);
uniform vec4 cloud_color : source_color = vec4(1.0,0.77,0.79,1.0);
uniform vec4 disc_color : source_color = vec4(1.0,0.86,0.76,1.0);
uniform vec3 disc_direction = vec3(0.0,0.4,0.9);
uniform float stars_strength = 0.0;
uniform float cloud_opacity = 0.38;
uniform float disc_radius = 0.012;

float hash21(vec2 p) {
 return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);
}
float noise21(vec2 p) {
 vec2 i = floor(p);
 vec2 f = fract(p);
 vec2 u = f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),u.x),mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0,1.0)),u.x),u.y);
}
void sky() {
 vec3 d = normalize(EYEDIR);
 float elevation = max(d.y,0.0);
 vec3 sky_color = mix(horizon.rgb,zenith.rgb,pow(elevation,0.48));
 sky_color = mix(ground_color.rgb,sky_color,smoothstep(-0.12,0.02,d.y));
 vec2 cloud_uv = d.xz/(abs(d.y)+0.28)*2.0;
 float clouds = noise21(cloud_uv)*0.6+noise21(cloud_uv*2.1)*0.28+noise21(cloud_uv*4.3)*0.12;
 float cloud_mask = smoothstep(0.53,0.78,clouds)*smoothstep(0.01,0.2,d.y)*cloud_opacity;
 sky_color = mix(sky_color,cloud_color.rgb,cloud_mask);
 float toward = max(0.0,dot(d,normalize(disc_direction)));
 float disc = smoothstep(cos(disc_radius),cos(disc_radius*0.7),toward);
 sky_color += disc_color.rgb*(disc*2.2+pow(toward,96.0)*0.17);
 // Spherical, deterministic stars: no texture assets or camera-relative particles.
 vec2 star_uv = vec2(atan(d.z,d.x)/6.2831853+0.5,acos(clamp(d.y,-1.0,1.0))/3.14159265)*vec2(850.0,425.0);
 vec2 cell = floor(star_uv);
 vec2 point = fract(star_uv)-vec2(hash21(cell+3.4),hash21(cell+19.7));
 float radius = 0.09+hash21(cell+7.1)*0.13;
 float star = (1.0-smoothstep(radius*0.2,radius,length(point)))*step(0.986,hash21(cell+41.8));
 vec3 star_tint = mix(vec3(0.65,0.8,1.0),vec3(1.0,0.85,0.68),hash21(cell+8.6));
 float belt = pow(max(0.0,1.0-abs(dot(d,normalize(vec3(0.4,0.7,-0.5))))),16.0);
 sky_color += stars_strength*smoothstep(0.02,0.18,d.y)*(star_tint*star*2.5+vec3(0.025,0.03,0.065)*belt)*(1.0-cloud_mask);
 COLOR = sky_color;
}
