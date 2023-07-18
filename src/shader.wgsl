
@group(0) @binding(0) var<uniform> projection: mat4x4<f32>;
@group(0) @binding(1) var<uniform> xform: mat4x4<f32>;



@vertex 
fn vertex_main(
	@builtin(vertex_index) index: u32
) -> @builtin(position) vec4<f32> {
	var pos = array<vec2<f32>, 6>(
		vec2<f32>(-16.0, -16.0),
		vec2<f32>( 16.0, -16.0),
		vec2<f32>( 16.0,  16.0),
		vec2<f32>( 16.0,  16.0),
		vec2<f32>(-16.0,  16.0),
		vec2<f32>(-16.0, -16.0)
	);

	return projection * xform * vec4<f32>(pos[index], 0.0, 1.0);
}

@fragment
fn fragment_main(
	@builtin(position) pos: vec4<f32>
) -> @location(0) vec4<f32> {
	return pos;
	//return vec4<f32>(1.0, 0.0, 0.0, 1.0);
}
