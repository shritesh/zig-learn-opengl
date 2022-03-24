#version 330 core

struct Material {
    sampler2D texture_diffuse1;
    sampler2D texture_specular1;
}; 

out vec4 FragColor;

in vec3 FragPos;  
in vec3 Normal;  
in vec2 TexCoords;

uniform vec3 viewPos;
uniform vec3 lightPos;
uniform Material material;

void main()
{    
    // diffuse 
    vec3 norm = normalize(Normal);
    vec3 lightDir = normalize(lightPos - FragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * texture(material.texture_diffuse1, TexCoords).rgb;  

    // specular
    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-lightDir, norm);  
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    vec3 specular = spec * texture(material.texture_specular1, TexCoords).rgb;  

    FragColor = vec4(diffuse + specular, 1.0);
}