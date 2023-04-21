class WebGLRenderer {
    meshes = [];
    shadowMeshes = [];
    lights = [];

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

    render() {
        const gl = this.gl;

        gl.clearColor(0.0, 0.0, 0.0, 1.0); // Clear to black, fully opaque
        gl.clearDepth(1.0); // Clear everything
        gl.enable(gl.DEPTH_TEST); // Enable depth testing
        gl.depthFunc(gl.LEQUAL); // Near things obscure far things

        console.assert(this.lights.length != 0, "No light");
        // console.assert(this.lights.length == 1, "Multiple lights");
        const timer = Date.now() * 0.00025;
        // let lightPos = [ Math.sin(timer * 6) * 100, 
        //                  80,
        //                  Math.cos(timer * 2) * 100 ];

        let lightPos = [0, 80, 80];
        for (let l = 0; l < this.lights.length; l++) {
            // Draw light
            // TODO: Support all kinds of transform
            this.lights[l].meshRender.mesh.transform.translate = lightPos;
            this.lights[l].meshRender.draw(this.camera);

            let lightMvp = this.lights[l].entity.CalcLightMVP(lightPos,[1, 1, 1]);
            // Shadow pass
            if (this.lights[l].entity.hasShadowMap == true) {
                for (let i = 0; i < this.shadowMeshes.length; i++) {
                    
                    // this.shadowMeshes[i].material.uniforms['uLightMVP'] =  { type: 'matrix4fv', value: lightMvp };
                    // let value = this.shadowMeshes[i].material.uniforms['uLightMVP'];
                    // this.shadowMeshes[i].material.uniforms.uLightMVP =  value;

                    this.gl.uniformMatrix4fv(
                        this.shadowMeshes[i].shader.program.uniforms.uLightMVP,
                        false,
                        lightMvp);

                    this.shadowMeshes[i].draw(this.camera);

                }
            }

            // Camera pass
            for (let i = 0; i < this.meshes.length; i++) {
                this.gl.useProgram(this.meshes[i].shader.program.glShaderProgram);
                this.gl.uniform3fv(this.meshes[i].shader.program.uniforms.uLightPos, lightPos);

                // this.meshes[i].material.uniforms['uLightMVP'] = { type: 'matrix4fv', value: lightMvp };
                // let value = this.meshes[i].material.uniforms['uLightMVP'];
                // value = {type: 'matrix4fv', value: lightMvp };
                // this.meshes[i].material.uniforms['uLightMVP'] = value;

                this.gl.uniformMatrix4fv(
					this.meshes[i].shader.program.uniforms.uLightMVP,
					false,
					lightMvp);
                    
                this.meshes[i].draw(this.camera);
            }
        }
    }
}