#include <cmath>
#include <algorithm>

#include "denoiser.h"
#include "util/mathutil.h"

#define M_PI 3.14159265358979323846 // pi

Denoiser::Denoiser() : m_useTemportal(false) {}

void Denoiser::Reprojection(const FrameInfo &frameInfo) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    Matrix4x4 preWorldToScreen =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 1];
    Matrix4x4 preWorldToCamera =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 2];
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Reproject
            m_valid(x, y) = false;
            m_misc(x, y) = Float3(0.f);
        }
    }
    std::swap(m_misc, m_accColor);
}

void Denoiser::TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    int kernelRadius = 3;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Temporal clamp
            Float3 color = m_accColor(x, y);
            // TODO: Exponential moving average
            float alpha = 1.0f;
            m_misc(x, y) = Lerp(color, curFilteredColor(x, y), alpha);
        }
    }
    std::swap(m_misc, m_accColor);
}

Float3 Denoiser::JointBilateralFilter(int kernelRadius, int pixelx, int pixely,
                              const FrameInfo &frameInfo) {

    auto DPlane = [](Float3 normal, Float3 position1, Float3 position2) -> float {
        float v = Dot(normal, Normalize(position1 - position2));
        return v * v;
    };

    auto DNormal = [](Float3 normal1, Float3 normal2) {
        float v = SafeAcos(Dot(normal1, normal2));
        return v * v;
    };

    auto Exponent = [](float difference, float sigma) {
        float sigma2 = Sqr(sigma);
        float exponent = exp(-difference / (2.0f * sigma2));
        return exponent;
    };

    Float3 position = (pixelx, pixely, 0.0f);
    Float3 color = frameInfo.m_beauty(pixelx, pixely);
    Float3 normal = frameInfo.m_normal(pixelx, pixely);
    float depth = frameInfo.m_depth(pixelx, pixely);
    Float3 precolor = m_preFrameInfo.m_beauty(pixelx, pixely);

    int pad = floor(kernelRadius / 2.0f);
    Float3 sumOfWightedValue = 0.0f;
    float sumofWeight = 0.0f;

    for (int i = 0; i < kernelRadius; i ++) 
    {
        int x = std::clamp(i - pad, 0, kernelRadius);
        for (int j = 0; j < kernelRadius; j ++)
        {
            int y = std::clamp(j - pad, 0, kernelRadius);

            Float3 positionj = (x, y, 0.0f);
            Float3 colorj = frameInfo.m_beauty(x, y);
            Float3 normalj = frameInfo.m_normal(x, y);
            float depthj = frameInfo.m_depth(x, y);

            float weightCoord = Exponent(SqrLength(position - positionj), m_sigmaCoord);
            float weightColor = Exponent(SqrLength(color - colorj), m_sigmaColor);
            float dnormal = Exponent(DNormal(normal, normalj), m_sigmaNormal);
            float dplane = Exponent(DPlane(normal, position, positionj), m_sigmaPlane);

            float weight = (weightCoord * weightColor * dnormal * dplane);
            sumOfWightedValue += color * weight;
            sumofWeight += weight;
        }
    }

    return sumOfWightedValue / sumofWeight;
}

Buffer2D<Float3> Denoiser::Filter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> filteredImage = CreateBuffer2D<Float3>(width, height);
    int kernelRadius = 16;
    
//#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Joint bilateral filter
            filteredImage(x, y) = JointBilateralFilter(kernelRadius, x, y, frameInfo);
        }
    }
    return filteredImage;
}

void Denoiser::Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor) {
    m_accColor.Copy(filteredColor);
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    m_misc = CreateBuffer2D<Float3>(width, height);
    m_valid = CreateBuffer2D<bool>(width, height);
}

void Denoiser::Maintain(const FrameInfo &frameInfo) { m_preFrameInfo = frameInfo; }

Buffer2D<Float3> Denoiser::ProcessFrame(const FrameInfo &frameInfo) {
    // Filter current frame
    Buffer2D<Float3> filteredColor;
    filteredColor = Filter(frameInfo);

    // Reproject previous frame color to current
    if (m_useTemportal) {
        Reprojection(frameInfo);
        TemporalAccumulation(filteredColor);
    } else {
        Init(frameInfo, filteredColor);
    }

    // Maintain
    Maintain(frameInfo);
    if (!m_useTemportal) {
        m_useTemportal = true;
    }
    return m_accColor;
}
