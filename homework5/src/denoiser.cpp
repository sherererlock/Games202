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
            float id = frameInfo.m_id(x, y);
            if (id == -1.0f) {
                m_valid(x, y) = false;
                m_misc(x, y) = Float3(0.0f);
                continue;
            }

            Matrix4x4 m2w = frameInfo.m_matrix[(int)id];
            Matrix4x4 w2m = Inverse(m2w);
            Matrix4x4 prem2w = m_preFrameInfo.m_matrix[(int)id]; // 上一帧的矩阵
            Matrix4x4 prem2s = preWorldToScreen * prem2w * w2m;

            Float3 position = frameInfo.m_position(x, y);
            Float3 screenPos = prem2s(position, Float3::EType::Point);

            if (screenPos.x < 0 || screenPos.x > width || screenPos.y < 0 || screenPos.y > height)
                continue;

            float preid = m_preFrameInfo.m_id((int)screenPos.x, (int)screenPos.y);// 当前像素上一帧物体id
            if (preid == id) {
                m_valid(x, y) = true;
                m_misc(x, y) = m_accColor((int)screenPos.x, (int)screenPos.y);
            }
        }
    }
    std::swap(m_misc, m_accColor);
}

void Denoiser::CalcMeanAndVariance(const Buffer2D<Float3> &curFilteredColor, int px, int py,
                                   int kernelRadius, Float3 &mean, Float3 &Variance) {
    int pad = (int)floor(kernelRadius / 2.0f);
    Float3 sumOfWightedValue = 0.0f;
    Float3 sumOfWightedSqrValue = 0.0f;

    float sumofWeight = 0.0f;

#pragma omp parallel for
    for (int i = 0; i < kernelRadius; i++) {
        int x = i - pad + px;
        if (x < 0)
            continue;

        for (int j = 0; j < kernelRadius; j++) {
            int y = j - pad + py;
            if (y < 0)
                continue;

            Float3 color = curFilteredColor(x, y);
            sumOfWightedSqrValue += (color * color);
            sumOfWightedValue += color;
            sumofWeight++;
        }
    }

    mean = sumOfWightedValue / sumofWeight;
    Float3 sqrmean = sumOfWightedSqrValue / sumofWeight;
    Variance = sqrmean - mean * mean;
}

void Denoiser::TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    int kernelRadius = 7;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Temporal clamp

            float alpha = 1.0f;
            Float3 color = m_accColor(x, y); // 上一帧的color

            bool valid = m_valid(x, y);
            if (valid) {
                alpha = m_alpha;

                Float3 mean;
                Float3 Variance;
                CalcMeanAndVariance(curFilteredColor, x, y, kernelRadius, mean, Variance);

                color = Clamp(color, mean - Variance * m_colorBoxK, mean + Variance * m_colorBoxK);
            }

            m_misc(x, y) = Lerp(color, curFilteredColor(x, y), alpha);
        }
    }
    std::swap(m_misc, m_accColor);
}

Float3 Denoiser::JointBilateralFilter(int kernelRadius, int pixelx, int pixely,
                              const FrameInfo &frameInfo) {

    auto DPlane = [](Float3 normal, Float3 position1, Float3 position2) -> float {
        Float3 vec = position1 - position2;
        if (Length(vec) == 0.0f)
            return 0.0f;
        float v = Dot(normal, Normalize(vec));
        return v * v;
    };

    auto DNormal = [](Float3 normal1, Float3 normal2) {
        float dot = Dot(normal1, normal2);
        float v = SafeAcos(dot);
        return v * v;
    };

    auto ExponentCoe = [](float difference, float sigma) {
        return -difference / (2.0f * Sqr(sigma));
    };

    Float3 position = (pixelx, pixely, 0.0f);
    Float3 color = frameInfo.m_beauty(pixelx, pixely);
    Float3 normal = frameInfo.m_normal(pixelx, pixely);
    float depth = frameInfo.m_depth(pixelx, pixely);

    int pad = (int)floor(kernelRadius / 2.0f);
    Float3 sumOfWightedValue = 0.0f;
    float sumofWeight = 0.0f;

    //std::cout << "(" << pixelx << "," << pixely << ")" << std::endl;
    #pragma omp parallel for
    for (int i = 0; i < kernelRadius; i ++) 
    {
        int x = i - pad + pixelx;
        if (x < 0)
            continue;

        for (int j = 0; j < kernelRadius; j ++)
        {
            int y = j - pad + pixely;
            if (y < 0)
                continue;

            Float3 positionj = (x, y, 0.0f);
            Float3 colorj = frameInfo.m_beauty(x, y);
            Float3 normalj = frameInfo.m_normal(x, y);
            float depthj = frameInfo.m_depth(x, y);

            float CoordCoe = ExponentCoe(SqrLength(position - positionj), m_sigmaCoord);
            float ColorCoe = ExponentCoe(SqrLength(color - colorj), m_sigmaColor);
            float dnormal = ExponentCoe(DNormal(normal, normalj), m_sigmaNormal);
            float dplane = ExponentCoe(DPlane(normal, position, positionj), m_sigmaPlane);

            //std::cout << "(" << x << "," << y << ")";
            float weight = std::exp(CoordCoe + ColorCoe + dnormal + dplane);

            sumOfWightedValue += colorj * weight;
            sumofWeight += weight;
        }
    }

    //std::cout << std::endl
    //          << "sumofWeight: " << sumofWeight << " sumOfWightedValue "
    //          << sumOfWightedValue << std::endl;

    return sumOfWightedValue / std::max(sumofWeight, 0.00001f);
}

Buffer2D<Float3> Denoiser::Filter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> filteredImage = CreateBuffer2D<Float3>(width, height);
    int kernelRadius = 32;
    
#pragma omp parallel for
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
