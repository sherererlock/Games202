#version 300 es

#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform sampler2D uGDiffuse;
uniform sampler2D uGDepth;
uniform sampler2D uGNormalWorld;
uniform sampler2D uGShadow;
uniform sampler2D uGPosWorld;

uniform sampler2D uDepthTexture[12];

// varying mat4 vWorldToScreen;
// varying highp vec4 vPosWorld;

in mat4 vWorldToScreen;
in vec4 vPosWorld;

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

#define MAX_MIPMAP_LEVEL 11
#define MAX_THICKNESS 0.0017

out vec4 FragColor;

float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec4 Project(vec4 a) {
  return a / a.w;
}

float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

float GetGBufferDepth(vec2 uv) {
  float depth = texture(uGDepth, uv).x;
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture(uGPosWorld, uv).xyz;
  return posWorld;
}

float GetGBufferuShadow(vec2 uv) {
  float visibility = texture(uGShadow, uv).x;
  return visibility;
}

vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo are all in world space.
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */

 float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = M_PI * denom * denom;

    return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float num   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}  

vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {
  vec3 L = vec3(0.0);

  wi = normalize(wi);
  wo = normalize(wo);

  vec3 normal = GetGBufferNormalWorld(uv);
  vec3 color = GetGBufferDiffuse(uv);

  vec3 H = normalize(wi + wo);

  float metallic= 0.5;
  float roughness = 0.5;
  vec3 F0 = mix(vec3(0.04), color, metallic);

  vec3 F = fresnelSchlick(max(dot(H, wo), 0.0), F0);

  float G = GeometrySmith(normal, wo, wi, roughness);
  float NDF = DistributionGGX(normal, H, roughness);

  vec3 kS = F;
  vec3 kD = vec3(1.0) - kS;
  kD *= (1.0 - metallic);

  float denom = 4.0 * (max(dot(normal, wi), 0.0)) * max(dot(normal, wo), 0.0) + 0.0001;
  vec3 nom = F * G * NDF;

  vec3 specular = nom / denom;

  float ndotl =  max(dot(normal, wi), 0.0);
  return (kD * color * INV_PI + specular) * ndotl;
}

vec3 EvalDiffuseLambertian(vec3 wi, vec3 wo, vec2 uv) {
  vec3 albedo  = GetGBufferDiffuse(uv);
  vec3 normal = GetGBufferNormalWorld(uv);
  float cos = max(0., dot(normal, wi));
  return albedo * cos * INV_PI;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 uv) {
  float visibility = GetGBufferuShadow(uv);
  return  uLightRadiance * visibility;
}

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) 
{
  float marchStep = 0.05;
  const int maxStep = 150;

  vec3 stepVec = dir * marchStep;
  vec3 marchPos = ori;
  for(int i = 0; i < maxStep; i ++)
  {
    vec2 uv = GetScreenCoordinate(marchPos);
    float marchDepth = GetDepth(marchPos);
    float depthInBuffer = GetGBufferDepth(uv);

    if(marchDepth - depthInBuffer > 0.001)
    {
      hitPos = GetGBufferPosWorld(uv);
      return true;
    }

    marchPos += stepVec;
  }

  return false;
}

ivec2 getCellCount(int level){
  if(level == 0){
    return textureSize(uDepthTexture[0], level);
  }
  else if(level == 1){
    return textureSize(uDepthTexture[1], level);
  }
  else if(level == 2){
    return textureSize(uDepthTexture[2], level);
  }
    else if(level == 3){
    return textureSize(uDepthTexture[3], level);
  }
    else if(level == 4){
    return textureSize(uDepthTexture[4], level);
  }
    else if(level == 5){
    return textureSize(uDepthTexture[5], level);
  }
    else if(level == 6){
    return textureSize(uDepthTexture[6], level);
  }
    else if(level == 7){
    return textureSize(uDepthTexture[7], level);
  }
    else if(level == 8){
    return textureSize(uDepthTexture[8], level);
  }
    else if(level == 9){
    return textureSize(uDepthTexture[9], level);
  }
    else if(level == 10){
    return textureSize(uDepthTexture[10], level);
  }
    else if(level == 11){
    return textureSize(uDepthTexture[11], level);
  }

  return textureSize(uDepthTexture[0], level);
}

ivec2 getCell(vec2 pos, ivec2 startCellCount){
 return ivec2(floor(pos*vec2(startCellCount)));
}

vec3 intersectDepthPlane(vec3 o, vec3 d, float t){
    return o + d * t;
}

vec3 intersectCellBoundary(vec3 o, vec3 d, ivec2 rayCell, ivec2 cell_count, vec2 crossStep, vec2 crossOffset){
    	vec3 intersection = vec3(0.);
	
      vec2 index = vec2(rayCell) + crossStep;
      vec2 boundary = index / vec2(cell_count);
      boundary += crossOffset;
      
      vec2 delta = boundary - o.xy;
      delta /= d.xy;
      float t = min(delta.x, delta.y);
      
      intersection = intersectDepthPlane(o, d, t);
      
      return intersection;
}

float getMinimumDepthPlane(vec2 pos, int level){
  vec2 cellCount = vec2(getCellCount(level));
  ivec2 cell = ivec2(floor(pos * cellCount));

  if(level == 0){
    return texelFetch(uDepthTexture[0], cell, 0).x;
  }
  else if(level == 1){
    return texelFetch(uDepthTexture[1], cell, 0).x;
  }
  else if(level == 2){
    return texelFetch(uDepthTexture[2], cell, 0).x;
  }
    else if(level == 3){
    return texelFetch(uDepthTexture[3], cell, 0).x;
  }
    else if(level == 4){
    return texelFetch(uDepthTexture[4], cell, 0).x;
  }
    else if(level == 5){
    return texelFetch(uDepthTexture[5], cell, 0).x;
  }
    else if(level == 6){
    return texelFetch(uDepthTexture[6], cell, 0).x;
  }
    else if(level == 7){
    return texelFetch(uDepthTexture[7], cell, 0).x;
  }
    else if(level == 8){
    return texelFetch(uDepthTexture[8], cell, 0).x;
  }
    else if(level == 9){
    return texelFetch(uDepthTexture[9], cell, 0).x;
  }
    else if(level == 10){
    return texelFetch(uDepthTexture[10], cell, 0).x;
  }
    else if(level == 11){
    return texelFetch(uDepthTexture[11], cell, 0).x;
  }

    return texelFetch(uDepthTexture[0], cell, 0).x;
}

bool crossedCellBoundary(ivec2 oldCellIdx,ivec2 newCellIdx){
    return (oldCellIdx.x!=newCellIdx.x)||(oldCellIdx.y!=newCellIdx.y);
}

bool RayMarch_Hiz_In_Texture_Space(vec3 start, vec3 rayDir,float maxTraceDistance, out vec3 hitPos){
    vec2 crossStep = vec2(rayDir.x >= 0. ? 1 : -1, rayDir.y >= 0. ? 1 : -1);
    // vec2 crossOffset = crossStep / vec2(1024.0, 1024.0) / 128.;
    vec2 crossOffset = crossStep / vec2(2560.0,1440.0) / 128.;
    crossStep = clamp(crossStep, 0.0, 1.0);

    vec3 ray = start;
    float minZ = ray.z;
    float maxZ = ray.z + rayDir.z * maxTraceDistance;
    float deltaZ = (maxZ - minZ);

    vec3 o = ray;
    vec3 d = rayDir * maxTraceDistance;

    int startLevel = 0;
    int stopLevel = 0;
    ivec2 startCellCount = getCellCount(startLevel);


    ivec2 rayCell = getCell(ray.xy, startCellCount);
    ray = intersectCellBoundary(o, d, rayCell, startCellCount, crossStep, crossOffset * 64.);

    int level = startLevel;
    int iter = 0;
    bool isBackwardRay = rayDir.z < 0.;

    float Dir = isBackwardRay ? -1. : 1.;

    while( level >= stopLevel && ray.z * Dir <= maxZ * Dir && iter < 100){
        ivec2 cellCount = getCellCount(level);
        ivec2 oldCellIdx = getCell(ray.xy, cellCount);

        float cell_minZ = getMinimumDepthPlane(ray.xy, level);

        vec3 tmpRay = ((cell_minZ > ray.z) && !isBackwardRay) ? intersectDepthPlane(o, d, (cell_minZ - minZ) / deltaZ) : ray;

        ivec2 newCellIdx = getCell(tmpRay.xy, cellCount);

        float thickness = level == 0 ? (ray.z - cell_minZ) : 0.;
        bool crossed  = (isBackwardRay && (cell_minZ > ray.z))||(thickness > MAX_THICKNESS)|| crossedCellBoundary(oldCellIdx, newCellIdx);
        ray = crossed ? intersectCellBoundary(o, d, oldCellIdx, cellCount, crossStep, crossOffset) : tmpRay;

        level = crossed ? min(MAX_MIPMAP_LEVEL, level + 1): level - 1;
        ++iter;
    }
    bool intersected = (level < stopLevel);
    intersected = true;
    hitPos = intersected ? ray : vec3(0.0);
    return intersected;
}

bool RayMarch_Hiz(vec3 ori, vec3 dir, out vec3 hitPos) {
    float step = 0.05;
    float maxDistance = 7.5;

    int startLevel = 2;
    int stopLevel = 0;

    vec3 curPos = ori;
    int level = startLevel;
    while(level >= stopLevel && distance(ori, curPos) < maxDistance){
        float rayDepth = GetDepth(curPos);
        vec2 screenUV = GetScreenCoordinate(curPos);
        float gBufferDepth = getMinimumDepthPlane(screenUV, level);

        if(rayDepth - gBufferDepth > 0.0001){
          if(level == 0){
            hitPos = curPos;
            return true;
          }
          else{
            level = level - 1;
          }
        }
        else{
          level = min(MAX_MIPMAP_LEVEL, level + 1);
          vec3 stepDistance = (dir * step * float(level + 1));
          curPos += stepDistance;
        }
    }
    return false;
}

vec3 EvalIndirectionalLight(vec2 uv, vec3 normal) {
  const int sampleCount = 1;

  vec3 L = vec3(0.0);
  vec3 b1, b2;
  LocalBasis(normal, b1, b2);

  mat3 local2world = mat3(b1, b2, normal);

  vec3 wo = normalize(uCameraPos - vPosWorld.xyz);
  vec3 wi = normalize(uLightDir);

   vec3 dir1 = normalize(reflect(-wo, normal));
  
  for(int i = 0; i < sampleCount; i ++)
  {
    float s = InitRand(gl_FragCoord.xy);
    float pdf;
    vec3 localdir = SampleHemisphereCos(s, pdf);
    vec3 dir = normalize(local2world * localdir);

    vec3 hitpos;
    // dir = dir1;
    // pdf = 1.0;
    // if(RayMarch_Hiz(vPosWorld.xyz,dir, hitpos))
    if(RayMarch(vPosWorld.xyz,dir, hitpos))
    {
      vec2 hituv = GetScreenCoordinate(hitpos);
      vec3 hitlight = EvalDirectionalLight(hituv);
      vec3 hitbrdf = EvalDiffuse(wi, -dir, hituv);

      vec3 le = hitlight * hitbrdf;

      vec3 brdf = EvalDiffuse(dir, wo, uv);
      L += (le * brdf) / pdf;
    }
  }

  return L / float(sampleCount);
}

#define SAMPLE_NUM 100

void main() {

  vec3 L = vec3(0.0);

  vec2 uv = GetScreenCoordinate(vPosWorld.xyz);

  // 直接光
  vec3 wo = normalize(uCameraPos - vPosWorld.xyz);
  vec3 wi = normalize(uLightDir);
  vec3 brdf = EvalDiffuse(wi, wo, uv);
  vec3 normal = normalize(GetGBufferNormalWorld(uv));
  vec3 directL = EvalDirectionalLight(uv) * brdf;

  // 间接光
  vec3 indirectL = vec3(0.0);
  indirectL = EvalIndirectionalLight(uv, normal);

  L = directL + indirectL;
  vec3 color = pow(clamp(L, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));

  FragColor = vec4(color, 1.0);
}
