## Hierarchical Depth Buffers

为了加快深度查询的加速结构，做法与普通的图像mip链一样。

本篇文章展示了两种生成Hierarchical Depth Buffers的技术：

1. 如何为任意的（不要求时2的幂次方的）depth buffer生成mip链
2. 如何用compute快速生成一层downsampled  level

#### Introduction

`Hierarchical depth`(Hi-Z)在CPU或GPU上用来做遮挡剔除，适用于SSR, SSAO，体积雾等等技术。

通常，GPU会作为管线的一部分实现Hi-Z。如果被之前的图像遮挡， 在芯片缓存上做快速深度查询可以允许GPU跳过一整个tile的片元。

从高级别的mip读取深度来加速深度查询，与读取全分辨率的depth buffer快有以下两个原因

1. 高级别的mip上的一个像素在全分辨率上可以代表很多个像素
2. 高级别的mip buffer足够小，可以存在cache中

根据用法，mip层级上的像素存储其覆盖多个上一级的像素中深度得最大值，或者最小值，或者两者都存，两者都可以避免我们在shader中做进一步的计算。

------

### Technique 1: Generating the Full Mip Chain

将bounding volume投影到屏幕空间上得到一个size，利用这个size来选取合适的mip level。

深度查找应该使用**最近邻过滤**，因为插值最小值是没有用的，而且还会干扰深度mip链的预期分层性质。

对应关系：特定纹理坐标采样得到的值映射到全分辨率的buffer中应该周围像素中的最小值/最大值，这个最小值/最大值是在将同一纹理坐标映射到更高级别的mip leve时计算的。相同的纹理坐标，获取的值是在每层mip level上是相同的。

对于偶数的图像尺寸，一维情况下，在层级$$N$$上的第$$i$$个纹素，我们需要计算在$$N-1$$层上第$$2i$$和第$$2i+1$$个纹素的最小值，公式$$D_N[i] = min(D_{n-1}[2i], D_{n-1}[2i + 1])$$,映射关系是$$2-to-1$$

![image-20230531113941544](D:\URPRJ\Games202\homework3\doc\hiz-even.png)

对于奇数的图像尺寸，一维情况下，对于$$N-1$$层像素个数是奇数，$$dim_N = \lfloor \frac{dim_{N-1}}2\rfloor$$,意味着，N层的每个纹素覆盖了N-1层的3个纹素，所以计算公式为$$D_N[i] = min(D_{n-1}[2i], D_{n-1}[2i + 1], D_{n-1}[2i + 2])$$,

为了简单起见，上面的描述是在一维中完成的。对于二维来说，如果N-1级的两个维度都是偶数，那么N-1级的2x2 texel区域就会映射到N级的一个texel。如果一个维度是奇数，那么N-1级的2x3或3x2区域就会映射到N级的一个texel。如果两个维度都是奇数，那么由行和列扩展共享的 "角 "texel也必须被考虑，所以N-1级的3x3区域映射到N级的一个texel上。

## Example code

下面的GLSL片段着色器代码实现了刚才描述的算法。它应该为每个连续的mip级别运行，从级别1开始（级别0是全分辨率）。

```c
uniform sampler2D u_depthBuffer;
uniform int u_previousLevel;
uniform ivec2 u_previousLevelDimensions;

void main() {
	ivec2 thisLevelTexelCoord = ivec2(gl_FragCoord);
	ivec2 previousLevelBaseTexelCoord = 2 * thisLevelTexelCoord;

	vec4 depthTexelValues;
	depthTexelValues.x = texelFetch(u_depthBuffer,
                                    previousLevelBaseTexelCoord,
                                    u_previousLevel).r;
	depthTexelValues.y = texelFetch(u_depthBuffer,
                                    previousLevelBaseTexelCoord + ivec2(1, 0),
                                    u_previousLevel).r;
	depthTexelValues.z = texelFetch(u_depthBuffer,
                                    previousLevelBaseTexelCoord + ivec2(1, 1),
                                    u_previousLevel).r;
	depthTexelValues.w = texelFetch(u_depthBuffer,
                                    previousLevelBaseTexelCoord + ivec2(0, 1),
                                    u_previousLevel).r;

	float minDepth = min(min(depthTexelValues.x, depthTexelValues.y),
                         min(depthTexelValues.z, depthTexelValues.w));

    // Incorporate additional texels if the previous level's width or height (or both)
    // are odd.
	bool shouldIncludeExtraColumnFromPreviousLevel = ((u_previousLevelDimensions.x & 1) != 0);
	bool shouldIncludeExtraRowFromPreviousLevel = ((u_previousLevelDimensions.y & 1) != 0);
	if (shouldIncludeExtraColumnFromPreviousLevel) {
		vec2 extraColumnTexelValues;
		extraColumnTexelValues.x = texelFetch(u_depthBuffer,
                                              previousLevelBaseTexelCoord + ivec2(2, 0),
                                              u_previousLevel).r;
		extraColumnTexelValues.y = texelFetch(u_depthBuffer,
                                              previousLevelBaseTexelCoord + ivec2(2, 1),
                                              u_previousLevel).r;

		// In the case where the width and height are both odd, need to include the
        // 'corner' value as well.
		if (shouldIncludeExtraRowFromPreviousLevel) {
			float cornerTexelValue = texelFetch(u_depthBuffer,
                                                previousLevelBaseTexelCoord + ivec2(2, 2),
                                                u_previousLevel).r;
			minDepth = min(minDepth, cornerTexelValue);
		}
		minDepth = min(minDepth, min(extraColumnTexelValues.x, extraColumnTexelValues.y));
	}
	if (shouldIncludeExtraRowFromPreviousLevel) {
		vec2 extraRowTexelValues;
		extraRowTexelValues.x = texelFetch(u_depthBuffer,
                                           previousLevelBaseTexelCoord + ivec2(0, 2),
                                           u_previousLevel).r;
		extraRowTexelValues.y = texelFetch(u_depthBuffer,
                                           previousLevelBaseTexelCoord + ivec2(1, 2),
                                           u_previousLevel).r;
		minDepth = min(minDepth, min(extraRowTexelValues.x, extraRowTexelValues.y));
	}

	gl_FragDepth = minDepth;
}
```

### Caveats with this listing

当长宽中一方超过另一方的两倍时，`texelFetch`会造成访问越界的。

- clamp传入到方法中的坐标
- 使用`texture`进行采样，sampler的采样方式设置为clamp-to-edge

4次`texelFetch`可以换成一次`textureGather`

### An alternative method of generating the mip chain

