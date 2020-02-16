#version 330 core

in vec2 texCoord;

uniform sampler2D tex;
uniform vec4 color;
uniform float texInfluence;

out vec4 fragColor;

void main()
{
	fragColor = color * mix(texture(tex, texCoord), vec4(1, 1, 1, 1), texInfluence);
}
