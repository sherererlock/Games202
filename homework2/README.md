# Games202

#### 框架详解

类图

```mermaid
classDiagram
 class PerspectiveCamera{
	+ float fov;
	+ float aspect;
	+ float nearPlane;
	+ float farPlane;
}

class Mesh{
	+ Array~int~ indices;
	+ bool hasVerices;
	+ bool hasNormals;
	+ bool hasTexcoords;
	
	+ Array~vec3~ vertices;
	+ Array~vec3~ normals;
	+ Array~vec2~ texcoords;
	+ Array~T~ extraAttribs;
	+ string name;
}

class Material{
	map~string, mat~ flatten_uniforms;
	Array~T~ flatten_attribs
	string vsSrc;
	string fsSrc;
	void setMeshAttribs(extraAttribs);
	void compile(gl);
}
class EmissiveMaterial{
	float intensity;
	vec color;
}

class PhongMaterial{
	
}

class ShadowMaterial{
	
}

Material<|--EmissiveMaterial
Material<|--PhongMaterial
Material<|--ShadowMaterial

class Shader{
	webGl gl;
	glShader vs;
	glShader fs;
	glProgram program;
	
	+ glShader compileShader(src, srcType);
	+ glProgram linkShader(vs, fs);
	+ addShaderLocations(result, shaderLocation);
}

class Texture{
	+ glTexture texture;
	+ float w;
	+ float h;
	+ float format;
}

class FrameBufferObject{
	FrameBuffer framebuffer;
}

class PointLight{
	Mesh cube;
	EmissiveMaterial mat;
}

class DirectionalLight{
	+ vec3 lightpos;
	+ vec3 focalPoint;
	+ vec3 lightUp;
	+ bool hasShadowMap;
	+ FrameBufferObject fbo;
	+ Matrix CalcLightMVP(translate, scale);
}

class MeshRenderer{
	+Mesh mesh;
	+WebGl gl;
	+Material material;
	+Shader shader;
	+glVertexBuffer vertexBuffer;
	+glIndicesBuffer indicesBuffer;
	+glNormalBUffer normalBuffer;
	+glTexcoordBuffer texcoordBuffer;
	
	void draw(camera, transform)
}

class WebGLRenderer{
	+ webGL gl;
	+ PerspectiveCamera camera;
	+ Array~MeshRenderer~ meshRenderers;
	+ Array~PointLight~ Lights;
}

WebGLRenderer o-- MeshRenderer
WebGLRenderer o-- PointLight
WebGLRenderer o-- DirectionalLight
WebGLRenderer o-- PerspectiveCamera

MeshRenderer *-- Mesh 
Material o-- Texture
Material o-- FrameBufferObject
MeshRenderer *-- Material
MeshRenderer *-- Shader
```

流程

```javascript
function GAMES202Main()
{
    // Canvas获取WebGL的Context
    // Camera设置
    
    //PointLight创建
    //创建PointLight的MeshRender
    //WebGLRenderer.AddLight(PointLight)
    
    loadObj()
    {
        //加载Mesh
        
        // 格式
        // 属性名：属性值
        // { name: 'aVertexPosition', array: geo.attributes.position.array }
        // { name: 'aNormalPosition', array: geo.attributes.normal.array }
        // { name: 'aTextureCoord', array: geo.attributes.uv.array }
        // indices
        
        
        // 创建Texture
       	// colorMap
        
        //创建Material
        
        // uniforms
        //属性名：{type:"", value:值}
        // 'uSampler': { type: 'texture', value: colorMap },
        // 'uTextureSample': { type: '1i', value: textureSample }
        // 'uKd': { type: '3fv', value: mat.color.toArray() }
        
        // attribs
        //[]
        
        // VertexShader, FragmentShader
        
        //创建MeshRenderer
        // gl, mesh
        // 创建各种GLBuffer
        // 编译shader
        
        // WebGLRenderer.AddMesh(MeshRenderer)
    }
    
    createGUI();
    

	function mainLoop(now) {
        // 更新相机
		cameraControls.update();

		WebGLRenderer.render(guiParams);
         {
            // clear color depth
            // 启用深度测试，方法为gl.LEQUAL
            
            // 更新点光位置，画出点光模型
            
            // 画模型
            // useProgram
            // 传值，lightPos
            meshRenderer.draw();
            {
                // 更新相机矩阵
                
                // binding vertexbuffer
                // binding normalbuffer
                // bingding texcoordsbuffer
                // bingding indicesBuffer
                
                gl.useProgram(this.shader.program.glShaderProgram);
                
                // 传入mvp
                
                //传入cameraPos
                
                //传入uniforms，包括texture
                
                gl.drawElements(gl.TRIANGLES, vertexCount, type, offset);

            }
        }
		requestAnimationFrame(mainLoop);
	}
    requestAnimationFrame(mainLoop);
}
```

#### Attribute绑定流程

1. 以key形式在xxxMaterial的构造函数中声明，这一步将Attribute变量添加到了Material的attribs数组中

   ```javascript
           super({
               // Phong
               'uPrecomputeL[0]': { type: 'precomputeL', value: null},
               'uPrecomputeL[1]': { type: 'precomputeL', value: null},
               'uPrecomputeL[2]': { type: 'precomputeL', value: null},
   
           }, ['aPrecomputeLT'], vertexShader, fragmentShader, null);
   ```

2. 在meshRender中使用API将顶点属性传入到shader中

   ```javascript
   // Bind attribute mat3 - LT
   // 创建buffer
   // 绑定buffer
   // 写入buffer Data
   const buf = gl.createBuffer();
   gl.bindBuffer(gl.ARRAY_BUFFER, buf);
   gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(precomputeLT[guiParams.envmapId]), gl.STATIC_DRAW);
   
   // buffer 属性
   for (var ii = 0; ii < 3; ++ii) {
       gl.enableVertexAttribArray(this.shader.program.attribs['aPrecomputeLT'] + ii);
       gl.vertexAttribPointer(this.shader.program.attribs['aPrecomputeLT'] + ii, 3, gl.FLOAT, false, 36, ii * 12);
   }
   ```

#### Uniform的绑定

1. 以key-value形式在xxxMaterial的构造函数中声明，这一步将uniform变量添加到了Material的uniforms字典中

   ```javascript
   //例
   // type为了区分，调用合适的api传入到gpu中
   'uSampler': { type: 'texture', value: color }
   ```

2. 在meshRender中遍历Material的uniforms字典，根据type，将变量和变量名绑定起来传入到GPU Shader中

   ```javascript
   		let textureNum = 0;
   		for (let k in this.material.uniforms) {
   
   			if (this.material.uniforms[k].type == 'matrix4fv') {
   				gl.uniformMatrix4fv(
   					this.shader.program.uniforms[k],
   					false,
   					this.material.uniforms[k].value);
   			} else if (this.material.uniforms[k].type == 'matrix3fv') {
   				gl.uniformMatrix3fv(
   					this.shader.program.uniforms[k],
   					false,
   					this.material.uniforms[k].value);
   			} else if (this.material.uniforms[k].type == '3fv') {
   				gl.uniform3fv(
   					this.shader.program.uniforms[k],
   					this.material.uniforms[k].value);
   			} else if (this.material.uniforms[k].type == '1f') {
   				gl.uniform1f(
   					this.shader.program.uniforms[k],
   					this.material.uniforms[k].value);
   			} else if (this.material.uniforms[k].type == '1i') {
   				gl.uniform1i(
   					this.shader.program.uniforms[k],
   					this.material.uniforms[k].value);
   			} else if (this.material.uniforms[k].type == 'texture') {
   				gl.activeTexture(gl.TEXTURE0 + textureNum);
   				gl.bindTexture(gl.TEXTURE_2D, this.material.uniforms[k].value.texture);
   				gl.uniform1i(this.shader.program.uniforms[k], textureNum);
   				textureNum += 1;
   			} else if (this.material.uniforms[k].type == 'CubeTexture') {
   				gl.activeTexture(gl.TEXTURE0 + textureNum);
   				//console.log(cubeMap.texture)
   				gl.bindTexture(gl.TEXTURE_CUBE_MAP, cubeMaps[guiParams.envmapId].texture);
   				gl.uniform1i(this.shader.program.uniforms[k], textureNum);
   				textureNum += 1;
   			}
   		}
   ```

   #### 实现
   
   对于Light函数来说，只有9个Vector3，与具体的顶点无关，所以可以当作Uniform传入。
   对于Transport函数来说，每个顶点都有9个系数，所以当作Attribute传入。
   
   light函数
   
   1. 读入参数
   
      ```javascript
      /*
      1.1977 1.60291 2.37536
      0.058533 0.0122304 -0.049865
      0.0168805 0.0074171 -0.00583072
      -0.188584 -0.181485 -0.141815
      -0.045244 -0.03994 -0.0224991
      -0.0431019 -0.0421153 -0.0376654
      0.155307 0.15568 0.161365
      -0.0638864 -0.052282 -0.0260421
      0.492288 0.452274 0.376647
      */
      precomputeL = [
          // GraceCathedral
          [0] =  []
          // Indoor
          [1] =  []
          // Skybox
          [2] =  []
      ]
      ```
   
   2. 每帧绑定到uniformbuffer中
   
      - shader中的定义
   
        ```c
        uniform mat3 uPrecomputeL[3];
        ```
   
      - 将precomputeL中的数组组成Mat（以1列为一个矩阵）
   
      - 传入到shader uniform中
   
        ```javascript
        let mat3value = getMat3ValueFromRGB(precomputeL[guiParams.envmapId]);
        for(let j = 0; j < 3; u++)
        {
        	if(k == "uPrecomputeL["+j+"]")
        	{
        		gl.uniform3fv(this.meshs[i].shader.program.uniforms[k], false, mat3value[j]);
        	}
        }
        ```
   
   transport函数
   
   1. 读入参数
   
      ```javascript
      /*
      0.237564 0.168931 0.211381 -0.117442 -0.102071 0.142967 0.0438758 -0.0644268 0.0153399 
      0.223138 0.132852 0.193238 -0.152764 -0.0725009 0.102351 0.0330102 -0.109226 0.0428689 
      0.20074 0.155726 0.189029 -0.0660841 -0.0438276 0.145367 0.0394032 -0.0323416 -0.0189922 
      0.190699 0.149202 0.164722 -0.115262 -0.0648439 0.14193 0.00499147 -0.0812827 -0.0145762 
      ...
      */
      
      precomputeLT[i] = [
          0.237564, 0.168931 0.211381 -0.117442 -0.102071 0.142967 0.0438758 -0.0644268 0.0153399
          0.223138 0.132852 0.193238 -0.152764 -0.0725009 0.102351 0.0330102 -0.109226 0.0428689 
          //...
      ]
      ```
   
   2. 传入到GPU作为顶点属性
   
      ```javascript
      const buf = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, buf);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(precomputeLT[guiParams.envmapId]), gl.STATIC_DRAW);
      
      for (var ii = 0; ii < 3; ++ii) {
          gl.enableVertexAttribArray(this.shader.program.attribs['aPrecomputeLT'] + ii);
          gl.vertexAttribPointer(this.shader.program.attribs['aPrecomputeLT'] + ii, 3, gl.FLOAT, false, 36, ii * 12);
      }
      
      /*
      [0.237564, 0.168931 0.211381
      -0.117442 -0.102071 0.142967 
      0.0438758 -0.0644268 0.0153399]
      
      void gl.vertexAttribPointer(index, size, type, normalized, stride, offset);
      index
      指定要修改的顶点属性的索引
      size
      指定每个顶点属性的组成数量，必须是1，2，3或4。
      type
      指定数组中每个元素的数据类型
      normalized
      当转换为浮点数时是否应该将整数数值归一化到特定的范围
      stride
      一个GLsizei，以字节为单位指定连续顶点属性开始之间的偏移量(即数组中一行长度)。不能大于255。如果stride为0，则假定该属性是紧密打包的，即不交错属性，每个属性在一个单独的块中，下一个顶点的属性紧跟当前顶点之后。
      offset
      GLintptr (en-US)指定顶点属性数组中第一部分的字节偏移量。必须是类型的字节长度的倍数
      */
      ```

Shader中计算

```c
/*
1.1977 1.60291 2.37536
0.058533 0.0122304 -0.049865
0.0168805 0.0074171 -0.00583072
-0.188584 -0.181485 -0.141815
-0.045244 -0.03994 -0.0224991
-0.0431019 -0.0421153 -0.0376654
0.155307 0.15568 0.161365
-0.0638864 -0.052282 -0.0260421
0.492288 0.452274 0.376647
*/
/*
[0.237564, 0.168931 0.211381
-0.117442 -0.102071 0.142967 
0.0438758 -0.0644268 0.0153399]
*/

/*
(1.1977 1.60291 2.37536)* 0.237564
*/

/*
(1.1977, 0.058533, 0.0168805) * (0.237564, 0.168931 0.211381)
*/

attribute highp mat3 aPrecomputeLT;
uniform mat3 uPrecomputeL[3];
varying highp vec3 vColor;

vColor = 
```

