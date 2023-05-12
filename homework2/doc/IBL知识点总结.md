# Image-Based-Lighting知识点总结

[TOC]

## 前置知识

### 渲染方程

### 微平面理论

### Cook-Torrence BRDF

#### 法线分布函数

#### 菲涅尔反射函数

#### 几何遮挡函数

### 蒙特卡洛积分

why:

在某些情况下，对积分的求解非常困难，如在多维，不连续，无法获得原函数等情况下，所以要引入蒙特卡洛积分

what:

思想：通过大量重复试验，通过统计频率，来估计概率，从而得到问题的求解

how:

积分估计量的收敛与被积函数的维度等都无关， 只跟样本数有关。

蒙特卡洛的估计值与积分真值存在差异，这个差异就是用方差表示，方差的大小也就代表了误差的大小，常提到的**方差缩减**，目的就是降低误差。方差缩减的研究课题是**如何能做到不提高采样数，达到缩减误差的目的**。本篇文章后面介绍的重要性采样和拟蒙特卡洛就是方差缩减中的两种策略。

**随机数的生成**：如何生成符合指定概率分布特点的随机数？
思想：均匀分布的随机数在计算机中比较容易生成，所以找到如何将均匀分布的随机数映射成为符合指定概率分布pdf的方法即可。
方法：累积分布函数cdf的反函数可以将均匀分布的随机数转换为符合pdf的随机数

**分布变换**，向量是用(x,y,z)表示的，而在半球上采样方向用球坐标($$\theta$$, $$\phi$$)比较方便，所以生成的随机数是($$\theta$$, $$\phi$$)，如何转换成x,y,z?
举例：区间[0, 1]之间的概率密度函数为$$pdf_X(x) = 2x， Y = SinX$$，如何计算Y的$$pdf$$?
$$
pdf_Y(y) = pdf_X(x)*(|\frac{dy}{dx})|)^{-1}
$$
二维情况下需要用到雅可比矩阵的行列式，求得pdf后，再求cdf及其反函数即可。需要经过分布转换，($$\theta$$, $$\phi$$)到(x,y,z)的转换
$$
pdf_Y(y_1,y_2,..., y_n) = \frac {pdf_X(x_1,x_2,...x_n)} {|J_T|}
$$

$$
pdf(r,\theta,\phi) = r^2 sin\theta pdf(x,y,z)
$$

**重要性采样**解决的是怎么设计最优的概率分布的问题。

**拟蒙特卡洛**解决的是如何消除随机数产生的聚集问题，以缩减误差。

### 采样方法

推导公式的一般步骤：

1. 求积分域上的pdf函数
2. 作分布变换，将其变换为($$\theta$$, $$\phi$$)的pdf函数
3. 利用边缘概率密度公式和条件概率公式的到($$\theta$$, $$\phi$$)各自的概率密度函数
4. 求$$\theta$$, $$\phi$$各自的pdf的逆累计分布函数
5. 利用均匀分布的随机数，表示($$\theta$$, $$\phi$$)，进而表示x,y,z

#### 半球面均匀采样

均匀采样，概率密度为常数$$pdf(x,y,z) = c = \frac{1}{2\pi}$$,

则$$pdf(r,\theta,\phi) = \frac{sin\theta}{2\pi}$$

则根据边缘密度概率公式$$pdf(\theta) = \int_0^{2\pi}pdf(\theta,\phi)d\phi = \frac{sin\theta}{2\pi}$$

再根据条件概率公式可得$$pdf(\phi|\theta) =\frac{pdf(\theta,\phi)}{pdf(\theta)} = \frac1{2\pi}$$,

再计算累计分布函数及其反函数

用均匀随机数表示$$(\theta, \phi)$$

进而表示x,y,z

```cpp
float4 UniformSampleHemisphere( float2 E )
{
    float Phi = 2 * PI * E.x;
    float CosTheta = E.y;
    float SinTheta = sqrt( 1 - CosTheta * CosTheta );

    float3 H;
    H.x = SinTheta * cos( Phi );
    H.y = SinTheta * sin( Phi );
    H.z = CosTheta;

    float PDF = 1.0 / (2 * PI);

    return float4( H, PDF );
}
```

#### 重要性采样

解决的是怎么设计最优的概率分布的问题，增加收敛速度和模拟精确性

任意一个被积函数$$fx$$，它的最优概率密度函数是$$pdf(x) = \frac{|f(x)|}{\int{f(x)}dx}$$

##### Cosine-weighted 半球采样

1. 与$$cos\theta$$有关，概率密度为常数$$pdf(x,y,z) = \int c cos\theta d \omega = 1$$,得$$c = 1 / \pi$$

2. 则$$pdf(r,\theta,\phi) = \frac1{\pi} cos \theta sin \theta$$

3. 根据边缘密度概率公式$$pdf(\theta) = \int_0^{2\pi}pdf(\theta,\phi)d\phi =$$

4. 条件概率公式可得$$pdf(\phi|\theta) =\frac{pdf(\theta,\phi)}{pdf(\theta)} =$$,

5. 求$$\theta$$, $$\phi$$各自的pdf的逆累计分布函数

6. 则$$\theta = (cos(\sqrt{\xi_1}))^{-1}$$ $$ \phi = 2\pi \xi $$

7. 带入到球坐标可得
   $$
   x = sin \theta cos \phi = cos(2 \pi \xi_2)\sqrt{(1-\xi_1)}
   $$

   $$
   y = sin \theta sin \phi = sin(2 \pi \xi_2)\sqrt{(1-\xi_1)}
   $$

   $$
   z = cos \theta = \sqrt{\xi_1}
   $$

   

```cpp
float4 CosineSampleHemisphere( float2 E )
{
    float Phi = 2 * PI * E.x;
    float CosTheta = sqrt( E.y );
    float SinTheta = sqrt( 1 - CosTheta * CosTheta );

    float3 H;
    H.x = SinTheta * cos( Phi );
    H.y = SinTheta * sin( Phi );
    H.z = CosTheta;

    float PDF = CosTheta * (1.0 /  PI);

    return float4( H, PDF );
}
```

##### BRDF采样（GGX重要性采样）

在实时渲染中，采用的物理光照模型是基于微表面理论，需要统计微面元的法线分布，如图7所示，设D(m)是微表面的法线分布函数，有下列等式成立
$$
\int_\Omega D(m)(m \cdot n)d\omega = 1
$$
对于GGX来说，其中
$$
D(m) = \frac {\alpha^2} {\pi(1 + (m \cdot n)^2(\alpha^2 -1))^2}
$$
则最优概率密度函数
$$
pdf(\theta,\phi) =\frac {\alpha^2} {\pi(1 + (m \cdot n)^2(\alpha^2 -1))^2} cos \theta sin\theta
$$
则关于$$\theta$$的边缘密度概率函数为
$$
pdf(\theta) = \int_0^{2\pi} pdf(\theta, \phi) =\frac {\alpha^2} {\pi(1 + (m \cdot n)^2(\alpha^2 -1))^2} cos \theta sin\theta
$$
关于$$\phi$$的条件概率密度函数
$$
$$pdf(\phi|\theta) =\frac{pdf(\theta,\phi)}{pdf(\theta)} = 1 / 2\pi
$$
![image-20230506104838778](.\thetaphi.png)



```cpp
float4 ImportanceSampleGGX( float2 E, float a2 )
{
    float Phi = 2 * PI * E.x;
    float CosTheta = sqrt( (1 - E.y) / ( 1 + (a2 - 1) * E.y ) );
    float SinTheta = sqrt( 1 - CosTheta * CosTheta );

    float3 H;
    H.x = SinTheta * cos( Phi );
    H.y = SinTheta * sin( Phi );
    H.z = CosTheta;

    float d = ( CosTheta * a2 - CosTheta ) * CosTheta + 1;
    float D = a2 / ( PI*d*d );
    float PDF = D * CosTheta;

    return float4( H, PDF );
}
```

##### 拟蒙特卡洛

**拟蒙特卡洛**解决的是如何消除随机数产生的聚集问题，以缩减误差。相比于纯随机数，增加收敛速度

拟蒙特卡洛（Quasi Monte Carlo）积分估计技术的核心点是**积分估计时采用低差异序列（Low Discrepancy Sequence）来替换纯随机数**，它的优点是积分估计的收敛速度更快

数学家引入了**差异**（Discrepancy）这个概念，完全随机的样本具有很高的差异，但是完全平均的样本的差异为0，我们的目标就是找到一组有较低差异且不失随机性的序列，这就是**低差异序列**，以期望达到消除聚集的目的。



## IBL

### 假设

### 漫反射部分

#### IrradianceMap

#### Spherical Harmonics



### 镜面反射部分

#### pre-filtered environment map

#### BRDF integration map

## 参考文章

蒙特卡洛积分：https://zhuanlan.zhihu.com/p/146144853

重要性采样和多重重要性采样在路径追踪中的应用：https://zhuanlan.zhihu.com/p/360420413