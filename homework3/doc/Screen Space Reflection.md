## Screen Space Reflection

### Ray Marching

确定每个片段的反射。射线行进是反复延长或收缩一些矢量的长度或幅度的过程，以便探测或取样一些空间的信息。屏幕空间反射中的射线是围绕法线反射的位置向量。

直观地说，一条光线击中了场景中的某个点，反弹后沿反射位置矢量的相反方向行进，反弹到当前的片段上，沿位置矢量的相反方向行进，然后击中相机镜头，让你看到场景中某个点的颜色反映在当前片段上。SSR是对光线路径进行反向追踪的过程。它试图找到光线反弹并击中当前片段的反射点。每次迭代时，算法都会沿着反射光线对场景的位置或深度进行采样，每次都会询问光线是否与场景的几何形状相交。如果有交集，场景中的那个位置就有可能被当前的片段反射。

理想情况下，有一些分析方法可以准确地确定第一个交点。这个第一个交点是反映在当前片段中的唯一有效点。相反，这种方法更像是一场战舰游戏。你看不到交点（如果有的话），所以你从反射射线的基点开始，在反射的方向上边走边叫出坐标。每次呼叫，你都会得到一个答案，即你是否击中了什么东西。如果你确实撞到了什么东西，你就在那个区域周围尝试一些点，希望能找到确切的交点。

世界空间或者ViewSpace都行

### Vertex Positions

view space

### Vertex Normals

normal map中定义的normal是BTN空间下，需要将其转换到ViewSpace下

### Position Transformations

在viewspace下的点必须要转换到clip space下，我们才能获取这个点的深度，为了采样原先记录在depth buffer中的深度，我们需要将这点转换到屏幕坐标下得到uv，然后根据uv从depth buffer获取深度。之后就可以比较这两深度了。

### Reflected UV Coordinates

有几种方法可以实现SSR。该示例代码通过计算每个屏幕片段的反射UV坐标来开始反射过程。你可以跳过这一部分，直接去计算反射的颜色，而使用场景的最终渲染。

回想一下，UV坐标的范围是U和V从0到1，屏幕只是一个2D纹理的UV映射在屏幕大小的矩形上。知道了这一点，这个例子的代码实际上不需要场景的最终渲染来计算反射。相反，它可以计算出每个屏幕像素最终会使用什么UV坐标。这些计算出来的UV坐标可以被保存到帧缓冲区的纹理中，并在以后的场景渲染中使用。

```c
uniform mat4 lensProjection;

uniform sampler2D positionTexture;
uniform sampler2D normalTexture;

  float maxDistance = 15; // 步进的最大距离
  float resolution  = 0.3; // 
  int   steps       = 10;// 步进次数
  float thickness   = 0.5; //

  vec2 texSize  = textureSize(positionTexture, 0).xy;
  vec2 texCoord = gl_FragCoord.xy / texSize;

  vec4 positionFrom     = texture(positionTexture, texCoord);
  vec3 unitPositionFrom = normalize(positionFrom.xyz);
  vec3 normal           = normalize(texture(normalTexture, texCoord).xyz);
  vec3 pivot            = normalize(reflect(unitPositionFrom, normal));
```

