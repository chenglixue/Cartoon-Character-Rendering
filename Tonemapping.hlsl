#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// -------------------------------------------- variable definition --------------------------------------------
float _MaxLuminanice;
float _Contrast;
float _LinearSectionStart;
float _LinearSectionLength;
float _BlackTightnessC;
float _BlackTightnessB;

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

struct VSInput
{
    float4 positionL : POSITION;
    float2 uv : TEXCOORD0;
};

struct PSInput
{
    float4 positionH : SV_POSITION;
    float2 uv : TEXCOORD0;
};

// -------------------------------------------- function definition --------------------------------------------

////////////////////////////////
// Tone mapping begin
////////////////////////////////

static const float e = 2.71828;

// smoothstep(x,e0,e1)
float WFunction(float x, float e0, float e1)
{
    if(x <= e0) return 0.f;
    if(x >= e1) return 1.f;

    float m = (x - e0) / (e1 - e0);
    
    return m * m * 3.f - 2.f * m;
}

// smoothstep(x,e0,e1)
float HFunction(float x, float e0, float e1)
{
    if(x <= e0) return 0.f;
    if(x >= e1) return 1.f;

    return (x - e0) / (e1 - e0);
}

// https://www.desmos.com/calculator/gslcdxvipg?lang=zh-CN
// https://www.shadertoy.com/view/Xstyzn
float GTHelper(half x)
{
    float P = _MaxLuminanice;      // max luminanice[1, 100]
    float a = _Contrast;      // Contrast[1, 5]
    float m = _LinearSectionStart;    // Linear section start
    float l = _LinearSectionLength;     // Linear section length
    // Black tightness[1,3] & [0, 1]
    float c = _BlackTightnessC;    
    float b = _BlackTightnessB;

    // Linear region computation
    // l0 is the linear length after scale
    float l0 = (P - m) * l / a;
    float L0 = m - m / a;
    float L1 = m + (1 - m) / a;
    float L_x = m + a * (x - m);
    
    // Toe
    float T_x = m * pow((x / m), c) + b;

    // Shoulder
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = a * P / (P - S1);
    float S_x = P - (P - S1) * pow(e, -C2 * (x - S0) / P);
    
    float w0_x = 1 - WFunction(x, 0, m);    // Toe weight
    float w2_x = HFunction(x, m + l0, m + l0);  // linear weight
    float w1_x = 1 - w0_x - w2_x;   // shoulder weight

    return T_x * w0_x + L_x * w1_x + S_x * w2_x;
}

PSInput TonemappingVS(VSInput vsInput)
{
    PSInput vsOutput;

    vsOutput.positionH = TransformObjectToHClip(vsInput.positionL);
    vsOutput.uv = vsInput.uv;

    return vsOutput;
}

float4 TonemappingPS(PSInput psInput) : SV_TARGET
{
    float3 outputColor = 0.f;

    half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv);

    float r = GTHelper(mainTex.r);
    float g = GTHelper(mainTex.g);
    float b = GTHelper(mainTex.b);

    outputColor += float3(r, g, b);
    
    return float4(outputColor, mainTex.a);
}

////////////////////////////////
// Tone mapping end
////////////////////////////////
