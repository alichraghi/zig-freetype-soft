#version 430 core

in vec4 pos;
out vec2 texCoords;
void main(void) {
    gl_Position = vec4(pos.xy, 0, 1);
    texCoords = pos.zw;
};