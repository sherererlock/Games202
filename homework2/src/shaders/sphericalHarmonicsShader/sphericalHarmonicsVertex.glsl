

attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute highp mat3 aPrecomputeLT;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;

uniform mat3 uPrecomputeL[3];

varying highp vec3 vNormal;
varying highp vec3 vColor;

vec3 SHrecon(mat3 uPrecomputeLR, mat3 uPrecomputeLG, mat3 uPrecomputeLB, mat3 vPrecomputeLT){
    vec3 result = vec3(uPrecomputeLR[0][0], uPrecomputeLG[0][0], uPrecomputeLB[0][0]) * vPrecomputeLT[0][0] +
        vec3(uPrecomputeLR[0][1], uPrecomputeLG[0][1], uPrecomputeLB[0][1]) * vPrecomputeLT[0][1] +
        vec3(uPrecomputeLR[0][2], uPrecomputeLG[0][2], uPrecomputeLB[0][2]) * vPrecomputeLT[0][2] +
        vec3(uPrecomputeLR[1][0], uPrecomputeLG[1][0], uPrecomputeLB[1][0]) * vPrecomputeLT[1][0] +
        vec3(uPrecomputeLR[1][1], uPrecomputeLG[1][1], uPrecomputeLB[1][1]) * vPrecomputeLT[1][1] +
        vec3(uPrecomputeLR[1][2], uPrecomputeLG[1][2], uPrecomputeLB[1][2]) * vPrecomputeLT[1][2] +
        vec3(uPrecomputeLR[2][0], uPrecomputeLG[2][0], uPrecomputeLB[2][0]) * vPrecomputeLT[2][0] +
        vec3(uPrecomputeLR[2][1], uPrecomputeLG[2][1], uPrecomputeLB[2][1]) * vPrecomputeLT[2][1] +
        vec3(uPrecomputeLR[2][2], uPrecomputeLG[2][2], uPrecomputeLB[2][2]) * vPrecomputeLT[2][2];
    return result;
}


float L_dot_LT(mat3 PrecomputeL, mat3 PrecomputeLT) {
  vec3 L_0 = PrecomputeL[0];
  vec3 L_1 = PrecomputeL[1];
  vec3 L_2 = PrecomputeL[2];
  vec3 LT_0 = PrecomputeLT[0];
  vec3 LT_1 = PrecomputeLT[1];
  vec3 LT_2 = PrecomputeLT[2];
  return dot(L_0, LT_0) + dot(L_1, LT_1) + dot(L_2, LT_2);
}

void main(void) {

  vNormal = (uModelMatrix * vec4(aNormalPosition, 0.0)).xyz;
  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix *
                vec4(aVertexPosition, 1.0);

  // for(int i = 0; i < 3; i++)
  // {
  //   vColor[i] = L_dot_LT(aPrecomputeLT, uPrecomputeL[i]);
  // }                

  vColor = SHrecon(uPrecomputeL[0], uPrecomputeL[1], uPrecomputeL[2], aPrecomputeLT);
}