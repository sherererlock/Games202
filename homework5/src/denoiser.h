#pragma once

#define NOMINMAX
#include <string>

#include "filesystem/path.h"

#include "util/image.h"
#include "util/mathutil.h"

struct FrameInfo {
  public:
    Buffer2D<Float3> m_beauty;
    Buffer2D<float> m_depth;
    Buffer2D<Float3> m_normal;
    Buffer2D<Float3> m_position;
    Buffer2D<float> m_id;
    std::vector<Matrix4x4> m_matrix;
};

class Denoiser {
  public:
    Denoiser();

    void Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor);
    void Maintain(const FrameInfo &frameInfo);

    void Reprojection(const FrameInfo &frameInfo);

    void CalcMeanAndVariance(const Buffer2D<Float3> &curFilteredColor, int x, int y, int kernelRadius, Float3 &mean, Float3 &Variance);

    void TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor);

    void CalcWeightedColorAndWeight(const FrameInfo &frameInfo, const Float3 &color,
                                    const Float3 &normal, const Float3 &position, int x,
                                    int y, Float3 &sumWeightedColor, float &sumWeight);

    Float3 JointBilateralFilter(int kernelRadius, int pixelx, int pixely,
                        const FrameInfo &frameInfo);
    Buffer2D<Float3> Filter(const FrameInfo &frameInfo);

    Buffer2D<Float3> ProcessFrame(const FrameInfo &frameInfo);

  public:
    FrameInfo m_preFrameInfo;
    Buffer2D<Float3> m_accColor;
    Buffer2D<Float3> m_misc;
    Buffer2D<bool> m_valid;
    bool m_useTemportal;

    float m_alpha = 0.2f;
    float m_sigmaPlane = 0.1f;
    float m_sigmaColor = 0.6f;
    float m_sigmaNormal = 0.1f;
    float m_sigmaCoord = 32.0f;
    float m_colorBoxK = 1.0f;
};