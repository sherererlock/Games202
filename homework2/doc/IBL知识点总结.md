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

光源在无限远处，模型上的相对位置可以忽略，即，模型上所有点的坐标都为原点。

类似于直接光照，根据Cook-Torrance BRDF模型可以将环境光照分为漫反射部分和镜面反射部分

![image-20230523102837308](.\renderequation_cook_torrence_brdf.png)

### 漫反射部分

![image-20230523102949657](D:\URPRJ\Games202\homework2\doc\diffuse_equation.png)

$$k_d = (1 - k_s)(1 - metalness)$$

$$ks = F(h,v)= F_0 +(1-F_0)(1-(h \cdot v))^5$$

$$h = \frac{(w_o+w_i)}{|w_o+w_i|}$$

等式h中包含有积分项（入射光方向）wi，无法进一步化简，所以做了近似。

![image-20230523103516218](D:\URPRJ\Games202\homework2\doc\fresnel_approximation.png)

得到

![image-20230523103609302](D:\URPRJ\Games202\homework2\doc\diffuse_equation_approximation.png)

所以我们只需要解决这个积分即可，而这个积分只与入射方向wi有关，我们可以在半球上采样预算出这一项，这就是`IrradianceMap`的来历。

#### IrradianceMap

对于上述积分，我们可以采样蒙特卡洛积分的方法进行计算，选取均匀采样或者重要性采样皆可。

对于均匀采样来说，$$pdf (\theta)= 1 / 0.5 \pi pdf(\phi) = 1/2\pi$$ 

![image-20230524101740432](C:\Users\admin\AppData\Roaming\Typora\typora-user-images\image-20230524101740432.png)

总之，我们在计算irradiance时，需要具体的法线信息n，需要根据法线信息在半球上随机分布入射方向wi，根据wi采样得到cubemap上的像素值作为Li，然后计算这个法线对应的irradiance，

得到这样一张存储了irradiance的贴图后，我们就可以根据法线采样得到shadingpoint的环境光照强度了

```c
//计算L(n)
for(normal &n: eachNormal)
{
    for(piexl &p: cubemap)
    {
        L(n) += p.color * dot(n,normalise(p.position));
    }
    L(n) /= smaplerNum;
}
//shader里面采样L(n)
color = texture(diffuseMap,normalise(n)).xyz;
```

### 镜面反射部分

对于镜面反射部分，由于其brdf过于复杂，无法像漫反射那样简单的将brdf近似为常数，所以我们使用名为`Split-Sum`的方法，将积分拆成两部分

![image-20230523105315803](D:\URPRJ\Games202\homework2\doc\intergration_approximation.png)

![image-20230523105354999](D:\URPRJ\Games202\homework2\doc\render_equation_approximatin.png)

我们将光照从积分中拆出去（对于后面的brdf函数来说，积分域较小，符合近似的条件）。这样我们就可以分别计算光照的积分和brdf的积分了。

#### pre-filtered environment map

对于前一项$$\frac{\int_\Omega L_i(p,w_i)dw_i}{\int_\Omega dw_i}$$来说，是对光照irradiance的加权平均，我们不能使用预计算漫反射的方式计算反射的光照，因为对于镜面反射来说，这个光照不仅仅与法线有关，还与我们的视角方向以及材质的粗糙度有关，所以做了一个假设，**令视角方向Wo=法线方向n=反射方向R**,这样后，我们将视角方向从方程中忽略了，只剩下反射方向和粗糙度。对于一个特定的粗糙度，我们用R预计算得到一张光照的贴图称之为`pre-filtered environment map`,一般我们会均匀的取粗糙度为 0, 0.25, 0.5, 0.75, 1.0，这样得到 5 个 cubemap，实时渲染时，利用R和粗糙度进行三线性插值。这里的R指定的视角方向的R，也即入射光的方向L

对于R的计算，首先我们需要在随机采样半程向量H，然后利用公式计算得到，注意这里的计算均不假定向量是normalized

![image-20230523114107209](D:\URPRJ\Games202\homework2\doc\calc_R.png)

虚幻中，还对得到的光照进行了加权平均，以法线和L的夹角点乘为权重计算加权平均，意义是，两者越接近，其权重越大，光照计算的更亮。

```
vec3 R = n;
vec3 V = w_o;
for(int i = 0; i < N; i++)
{
    vec3 randNum = randFunction();
    vec3 H = importanceSample(randNum,n);
    vec3 L = normalize(2.0 * dot(V, H) * H - V);
    color += texture(cubeMap,L).xyz * dot(n,L);
    weight += dot(n,L);
}
color /= weight;
```

计算不同的roughness对应的贴图时，只需要根据roughness计算出不同的miplevel即可

```c
            float saSample = 1.0 / (float(SAMPLE_COUNT) * pdf + 0.0001);

            float mipLevel = roughness == 0.0 ? 0.0 : 0.5 * log2(saSample / saTexel); 
```

这个假设之所以成立是因为，当物体材质是gloosy的时候，反射的波瓣较小，从不同的方向入射，反射方向都会集中在某一个区域内。

带来的问题是，当从掠射角度看物体时，无法看到正确的图像。

#### BRDF integration map

对于后一项，其变量有视角方向Wo，法线方向N，粗糙度roughness以及F0，由于GGX是各向同性的，所以wo与wi与法线的角度是相同的。所以只需要一个角度$$\theta$$即可，这样变量剩下$$\theta$$， roughness和F0，我们可以作如下近似，这个可以将原来的公式乘以$$F/F$$，然后展开F得到

![image-20230523114738590](D:\URPRJ\Games202\homework2\doc\brdf_int_approximation.png)

观察公式，我们可以得到形如$$R_0 * A + B$$的形式，对于A和B，我们都消去了F项，也就是只剩下roughness和$$\theta$$两个变量，我们可以生成一张图，预存A和B，它们的计算可以用根据法线分布函数进行重要性采样的蒙特卡洛积分来解决。

## 参考文章

蒙特卡洛积分：https://zhuanlan.zhihu.com/p/146144853

重要性采样和多重重要性采样在路径追踪中的应用：https://zhuanlan.zhihu.com/p/360420413