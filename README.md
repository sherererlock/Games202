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

#### Uniform的绑定

#### 阴影流程

```javascript
function GAMES202Main()
{
    // 添加产生阴影的光源信息
	let lightPos = [0, 80, 80];
	let focalPoint = [0, 0, 0];
	let lightUp = [0, 1, 0]
	const directionLight = new DirectionalLight(5000, [1, 1, 1], lightPos, focalPoint, lightUp, true, renderer.gl);
    {
        // 创建shadowMap的FrameBuffer
        this.fbo = new FBO(gl);
    }
	renderer.addLight(directionLight);
   
    function loadOBJ(renderer, path, name, objMaterial, transform)
    {
        // 创建着色材质和Shadow材质
        material = buildPhongMaterial(colorMap, mat.specular, light, Translation, Scale, "phongVertex.glsl", "phongFragment.glsl");
        {
            // 将light的FBO对象绑定到shader的uShadowMap上
        }
        shadowMaterial = buildShadowMaterial(light, Translation, Scale, "shadowVertex.glsl", "shadowFragment.glsl");
        {
            // 计算lightMVP
            let lightMVP = light.CalcLightMVP(translate, scale);
            
            // 将light的FBO对象绑定到材质的frameBuffer上
        }
        
        //添加模型和阴影模型
        let meshRender = new MeshRender(renderer.gl, mesh, data);
        renderer.addMeshRender(meshRender);
        let shadowMeshRender = new MeshRender(renderer.gl, mesh, data);
        renderer.addShadowMeshRender(shadowMeshRender);
    }
    
    WebGLRenderer.render() 
    {
        // light pass
        this.shadowMeshes[i].draw(this.camera);
        {
            // 将当前渲染的Target绑定为shadowMap的frameBuffer,以便shadow渲染
            gl.bindFramebuffer(gl.FRAMEBUFFER, this.material.frameBuffer);
            gl.viewport(0.0, 0.0, resolution, resolution);
        }
        
        // scene pass
        this.meshes[i].draw(this.camera);
        {
            this.bindMaterialParameters();
            {
                // 绑定fbo到uShadowMap上
            }
        }
    }
}
```

#### 问题

1. 采样shadowMap的纹理坐标的计算

   阴影贴图是在light空间下渲染的，所以相机空间下看到的shadingPoint需要转换到light空间下，这样才能在shadowmap上采样出正确的深度。其次采样的uv坐标也应该是shadowMap空间的uv坐标。shadingPoint的位置乘以lightMVP之后，将其转换到了裁剪空间下，还需要进行到NDC坐标的转换，首先得做透视除法，转换到了NDC空间下，也即坐标范围到了-1.0~1.0，必须要再做一次转换将其映射到0-1，适应纹理坐标是0-1之间的要求
