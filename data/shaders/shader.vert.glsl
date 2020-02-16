#version 330 core

//vec2 quad[4] = { vec2(-1, -1), vec2(-1, 1), vec2(1, 1), vec2(1, -1) };

uniform ivec2 vertices[4];
uniform vec2 texCoords[4];

uniform ivec2 view;
uniform ivec2 focus;

uniform ivec2 position;
uniform ivec2 offset;
uniform float facing; // -1 or 1
uniform float rotation = 0;
uniform vec2 scale = vec2(1, 1);

uniform sampler2D tex;
out vec2 texCoord;
uniform vec4 color;
uniform float texInfluence;

float map(float value, float srcMin, float srcMax, float dstMin, float dstMax)
{
	return (value - srcMin) * (dstMax - dstMin) / (srcMax - srcMin) + dstMin;
}

vec2 map(vec2 value, vec2 srcMin, vec2 srcMax, vec2 dstMin, vec2 dstMax)
{
	return (value - srcMin) * (dstMax - dstMin) / (srcMax - srcMin) + dstMin;
}

vec2 rotate(vec2 v, float a)
{
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, s, -s, c);
	return m * v;
}

void main()
{
	vec2 pos = vertices[gl_VertexID];
	texCoord = texCoords[gl_VertexID];
	gl_Position = vec4(
		map(
			rotate(
				pos * vec2(facing, 1) - offset, rotation
			) * scale + position + vec2(-focus + view / 2),
			vec2(0, 0),
			view,
			vec2(-1, -1),
			vec2(1, 1)
		),
		0.0,
		1.0
	);
}
