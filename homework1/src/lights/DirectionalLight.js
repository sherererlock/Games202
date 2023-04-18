class DirectionalLight {

    constructor(lightIntensity, lightColor, lightPos, focalPoint, lightUp, hasShadowMap, gl) {
        this.mesh = Mesh.cube(setTransform(0, 0, 0, 0.2, 0.2, 0.2, 0));
        this.mat = new EmissiveMaterial(lightIntensity, lightColor);
        this.lightPos = lightPos;
        this.focalPoint = focalPoint;
        this.lightUp = lightUp

        this.hasShadowMap = hasShadowMap;
        this.fbo = new FBO(gl);
        if (!this.fbo) {
            console.log("无法设置帧缓冲区对象");
            return;
        }
    }

    CalcLightMVP(translate, scale) {
        let lightMVP = mat4.create();
        let modelMatrix = mat4.create();
        let viewMatrix = mat4.create();
        let projectionMatrix = mat4.create();

        // Model transform
		mat4.identity(modelMatrix);
		mat4.translate(modelMatrix, modelMatrix, translate);
		mat4.scale(modelMatrix, modelMatrix, scale);

        // View transform
        mat4.lookAt(viewMatrix, this.lightPos, this.focalPoint, this.lightUp);
        // let up = this.lightUp.normalize();
        // let lookat = (this.lightPos - this.focalPoint).normalize();

        // let right = crossVectors(up, lookat);
        // right = normalize(right);
        // let newUp = crossVectors(lookat, right);
        // newUp = crossVectors(newUp);

        // let T = mat4.create();
        // T[3] = -this.lightPos.x;
        // T[7] = -this.lightPos.y;
        // T[11] = -this.lightPos.z;

        // let R = mat4.create();
        // R[0] = right.x;
        // R[4] = right.y;
        // R[8] = right.z;

        // R[1] = newUp.x;
        // R[5] = newUp.y;
        // R[9] = newUp.z; 

        // R[2] = lookat.x;
        // R[6] = lookat.y;
        // R[10] = lookat.z; 

        // let Rinv = R.invert();
        // viewMatrix = Rinv * T;

        // Projection transform
        mat4.ortho(projectionMatrix, -150.0, 150.0, -150.0, 150.0, 1e-2, 400);

        mat4.multiply(lightMVP, projectionMatrix, viewMatrix);
        mat4.multiply(lightMVP, lightMVP, modelMatrix);

        return lightMVP;
    }
}
