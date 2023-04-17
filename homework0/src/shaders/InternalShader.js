const LightCubeVertexShader = `
attribute vec3 aVertexPosition;

uniform mat4 uModelViewMatrix;
uniform mat4 uProjectionMatrix;


void main(void) {

  gl_Position = uProjectionMatrix * uModelViewMatrix * vec4(aVertexPosition, 1.0);

}
`;

const LightCubeFragmentShader = `
#ifdef GL_ES
precision mediump float;
#endif

uniform float uLigIntensity;
uniform vec3 uLightColor;

void main(void) {
    
  //gl_FragColor = vec4(1,1,1, 1.0);
  gl_FragColor = vec4(uLightColor, 1.0);
}
`;
const VertexShader = `
attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute vec2 aTextureCoord;

uniform mat4 uModelViewMatrix;
uniform mat4 uProjectionMatrix;

varying highp vec3 vFragPos;
varying highp vec3 vNormal;
varying highp vec2 vTextureCoord;

void main(void) {

  vFragPos = aVertexPosition;
  vNormal = aNormalPosition;

  gl_Position = uProjectionMatrix * uModelViewMatrix * vec4(aVertexPosition, 1.0);

  vTextureCoord = aTextureCoord;

}
`;

const FragmentShader = `
#ifdef GL_ES
precision mediump float;
#endif

uniform int uTextureSample;
uniform vec3 uKd;
uniform sampler2D uSampler;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;

varying highp vec3 vFragPos;
varying highp vec3 vNormal;
varying highp vec2 vTextureCoord;

void main(void) {
  
  if (uTextureSample == 1) {
    gl_FragColor = texture2D(uSampler, vTextureCoord);
  } else {
    gl_FragColor = vec4(uKd,1);
  }

}
`;

const PhongVertexShader = `
attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute vec2 aTextureCoord;

uniform mat4 uModelViewMatrix;
uniform mat4 uProjectionMatrix;

varying highp vec3 vFragPos;
varying highp vec3 vNormal;
varying highp vec2 vTextureCoord;

void main(void) {

  vFragPos = aVertexPosition;
  vNormal = aNormalPosition;

  gl_Position = uProjectionMatrix * uModelViewMatrix * vec4(aVertexPosition, 1.0);

  vTextureCoord = aTextureCoord;

}
`;

const PhongFragmentShader = `
#ifdef GL_ES
precision mediump float;
#endif

uniform vec3 uKd;
uniform vec3 uKs;

uniform float uLightIntensity;

uniform int uTextureSample;
uniform sampler2D uSampler;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;

varying highp vec3 vFragPos;
varying highp vec3 vNormal;
varying highp vec2 vTextureCoord;

void main(void) {
  vec3 color;

  if (uTextureSample == 1) {
    color = texture2D(uSampler, vTextureCoord).rgb;
    color = pow(color, vec3(2.2));
  } else {
    color = uKd;
  }

  vec3 l = uLightPos - vFragPos;
  float len = length(l);
  l = normalize(l);
  vec3 v = normalize(uCameraPos - vFragPos);
  vec3 n = normalize(vNormal);
  vec3 h = normalize(v + l);
  
  float atten_off = uLightIntensity / len ;

  vec3 amibient = 0.05 * color;
  vec3 diffuse = color * atten_off * max(dot(n, l), 0.0);
  vec3 specular = uKs * atten_off * pow(max(dot(n, h), 0.0), 35.0);

  vec3 glcolor = pow(amibient+diffuse+specular, vec3(1.0/2.2));

  gl_FragColor = vec4(glcolor,1);;
}
`;