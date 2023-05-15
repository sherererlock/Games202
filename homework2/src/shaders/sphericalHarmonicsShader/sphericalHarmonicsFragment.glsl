#ifdef GL_ES
precision mediump float;
#endif

varying highp vec3 vColor;

vec3 toSRGB()  {
    vec3 result;

    for (int i=0; i<3; ++i) {
        float value = vColor[i];

        if (value <= 0.0031308)
            result[i] = 12.92 * value;
        else
            result[i] = (1.0 + 0.055)
                * pow(value, 1.0/2.4) -  0.055;
    }

    return result;
}

void main(void) {
  vec3 color = toSRGB();
  gl_FragColor = vec4(color, 1.0);
}
