class SphericalHarmonicsMaterial extends Material {

    constructor(color, specular, light, translate, scale, vertexShader, fragmentShader) {
        let lightMVP = light.CalcLightMVP(translate, scale);
        let lightIntensity = light.mat.GetIntensity();

        super({
            // Phong

            'uLightMVP': { type: 'matrix4fv', value: lightMVP },

        }, ['aPrecomputeLT'], vertexShader, fragmentShader, null);
    }
}

async function buildSphericalHarmonicsMaterial(color, specular, light, translate, scale, vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new SphericalHarmonicsMaterial(color, specular, light, translate, scale, vertexShader, fragmentShader);

}