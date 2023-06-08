class WebGLRenderer {
    meshes = [];
    shadowMeshes = [];
    bufferMeshes = [];
    lights = [];

    depthFBOs = [];

    constructor(gl, camera) {
        this.gl = gl;
        this.camera = camera;
    }

    addLight(light) {
        this.lights.push({
            entity: light,
            meshRender: new MeshRender(this.gl, light.mesh, light.mat)
        });
    }
    addMeshRender(mesh) { this.meshes.push(mesh); }
    addShadowMeshRender(mesh) { this.shadowMeshes.push(mesh); }
    addBufferMeshRender(mesh) { this.bufferMeshes.push(mesh); }

    addDepthFBO(fbo) { this.depthFBOs.push(fbo); }

    render() {
        console.assert(this.lights.length != 0, "No light");
        console.assert(this.lights.length == 1, "Multiple lights");
        var light = this.lights[0];

        const gl = this.gl;
        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clearDepth(1.0);
        gl.enable(gl.DEPTH_TEST);
        gl.depthFunc(gl.LEQUAL);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // Update parameters
        let lightVP = light.entity.CalcLightVP();
        let lightDir = light.entity.CalcShadingDirection();
        let updatedParamters = {
            "uLightVP": lightVP,
            "uLightDir": lightDir,
        };

        // Draw light
        light.meshRender.mesh.transform.translate = light.entity.lightPos;
        light.meshRender.draw(this.camera, null, updatedParamters);

        // Shadow pass
        gl.bindFramebuffer(gl.FRAMEBUFFER, light.entity.fbo);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        for (let i = 0; i < this.shadowMeshes.length; i++) {
            this.shadowMeshes[i].draw(this.camera, light.entity.fbo, updatedParamters);
            // this.shadowMeshes[i].draw(this.camera);
        }
        // return;

        // Buffer pass
        gl.bindFramebuffer(gl.FRAMEBUFFER, this.camera.fbo);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        for (let i = 0; i < this.bufferMeshes.length; i++) {
            this.bufferMeshes[i].draw(this.camera, this.camera.fbo, updatedParamters);
            // this.bufferMeshes[i].draw(this.camera);
        }
        // return

        // Tag:WebGL2
        // depth mip pass
        for (let lv = 0; lv < this.depthFBOs.length && depthMeshRender !=null; lv++) {
            gl.useProgram(depthMeshRender.shader.program.glShaderProgram);
            gl.bindFramebuffer(gl.FRAMEBUFFER, this.depthFBOs[lv]);
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

            let updatedParamters = {
                "uLastMipSize": [this.depthFBOs[lv].lastWidth, this.depthFBOs[lv].lastHeight, 0],
                "uCurLevel": lv,
            };

            if(lv != 0){
                updatedParamters.uDepthMipMap = this.depthFBOs[lv - 1].textures[0];
            }

            depthMeshRender.bindGeometryInfo();
            depthMeshRender.updateMaterialParameters(updatedParamters);
            depthMeshRender.bindMaterialParameters();

            gl.viewport(0, 0, this.depthFBOs[lv].width, this.depthFBOs[lv].height);
            {
                const vertexCount = depthMeshRender.mesh.count;
                const type = gl.UNSIGNED_SHORT;
                const offset = 0;
                gl.drawElements(gl.TRIANGLES, vertexCount, type, offset);
            }
        }
        gl.bindTexture(gl.TEXTURE_2D, null);
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);        

        // Camera pass
        for (let i = 0; i < this.meshes.length; i++) {
            for(let lv = 0; lv < mipMapLevel; lv++){
                if(this.depthFBOs.length > lv){
                    updatedParamters['uDepthTexture' + '[' + lv + ']'] = this.depthFBOs[lv].textures[0];
                }
            }
            
            this.meshes[i].draw(this.camera, null, updatedParamters);
        }
    }
}