#version 330

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;
uniform vec2 iResolution;

// Output vertex attributes (to fragment shader)
out vec2 fragPos;

void main()
{
    fragPos = vec2(
        vertexPosition.x / iResolution.x,
        vertexPosition.y / iResolution.y
    );

    // Calculate final vertex position
    gl_Position = mvp*vec4(vertexPosition, 1.0);
}
