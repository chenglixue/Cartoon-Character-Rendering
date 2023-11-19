#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// -------------------------------------------- variable definition --------------------------------------------
CBUFFER_START(UnityPerMaterial)
float4 _MainTex_TexelSize;

CBUFFER_END

half _BlurIntensity;
float _LuminanceThreshold;
half4 _BloomColor;
float _BloomIntensity;

TEXTURE2D(_MainTex);    // 模糊后的RT
SAMPLER(sampler_MainTex);
TEXTURE2D(_SourceTex);  // 原RT
SAMPLER(sampler_SourceTex);


struct VSInput
{
    float4 positionL : POSITION;
    float2 uv : TEXCOORD0;
};

struct PSInput
{
    float4 positionH : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 uv01 : TEXCOORD1;
    float4 uv23 : TEXCOORD2;
    float4 uv45 : TEXCOORD3;
    float4 uv67 : TEXCOORD4;
};

// -------------------------------------------- function definition --------------------------------------------
half ExtractLuminance(half3 color)
{
    return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
}

////////////////////////////////
// 提取亮度
////////////////////////////////
PSInput ExtractLumVS(VSInput vsInput)
{
    PSInput vsOutput;

    vsOutput.positionH = TransformObjectToHClip(vsInput.positionL);
    vsOutput.uv = vsInput.uv;

    return vsOutput;
}

half4 ExtractLumPS(PSInput psInput) : SV_TARGET
{
    half3 outputColor = 0.f;

    half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv);
    half luminanceFactor = saturate(ExtractLuminance(mainTex) - _LuminanceThreshold);

    outputColor += mainTex * luminanceFactor;

    return half4(outputColor, 1.f);
}

////////////////////////////////
// DualBlur模糊
////////////////////////////////
PSInput DownSampleVS(VSInput vsInput)
{
    PSInput vsOutput;

    vsOutput.positionH = TransformObjectToHClip(vsInput.positionL);

    // 在D3D平台下，若开启抗锯齿，_TexelSize.y会变成负值
    #ifdef UNITY_UV_STARTS_AT_TOP
    if(_MainTex_TexelSize.y < 0)
        vsInput.uv.y = 1 - vsInput.uv.y;
    #endif
            
    vsOutput.uv = vsInput.uv;
    vsOutput.uv01.xy = vsInput.uv + float2(1.f, 1.f) * _MainTex_TexelSize.xy * _BlurIntensity;
    vsOutput.uv01.zw = vsInput.uv + float2(-1.f, -1.f) * _MainTex_TexelSize.xy * _BlurIntensity;
    vsOutput.uv23.xy = vsInput.uv + float2(1.f, -1.f) * _MainTex_TexelSize.xy * _BlurIntensity;
    vsOutput.uv23.zw = vsInput.uv + float2(-1.f, 1.f) * _MainTex_TexelSize.xy * _BlurIntensity;

    return vsOutput;
}

float4 DownSamplePS(PSInput psInput) : SV_TARGET
{
    float4 outputColor = 0.f;

    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv.xy) * 0.5;
    
    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv01.xy) * 0.125;
    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv01.zw) * 0.125;
    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv23.xy) * 0.125;
    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv23.zw) * 0.125;

    return outputColor;
}

PSInput UpSampleVS(VSInput vsInput)
{
    PSInput vsOutput;

    vsOutput.positionH = TransformObjectToHClip(vsInput.positionL);

    #ifdef UNITY_UV_STARTS_AT_TOP
    if(_MainTex_TexelSize.y < 0.f)
        vsInput.uv.y = 1 - vsInput.uv.y;
    #endif

    vsOutput.uv = vsInput.uv;
    // 1/12
    vsOutput.uv01.xy = vsInput.uv + float2(0, 1) * _MainTex_TexelSize.xy * _BlurIntensity;
    vsOutput.uv01.zw = vsInput.uv + float2(0, -1) * _MainTex_TexelSize.xy * _BlurIntensity;
    vsOutput.uv23.xy = vsInput.uv + float2(1, 0) * _MainTex_TexelSize.xy * _BlurIntensity;
    vsOutput.uv23.zw = vsInput.uv + float2(-1, 0) * _MainTex_TexelSize.xy * _BlurIntensity;
    // 1/6
    vsOutput.uv45.xy = vsInput.uv + float2(1, 1) * 0.5 * _MainTex_TexelSize.xy * _BlurIntensity;
    vsOutput.uv45.zw = vsInput.uv + float2(-1, -1) * 0.5 * _MainTex_TexelSize.xy * _BlurIntensity;
    vsOutput.uv67.xy = vsInput.uv + float2(1, -1) * 0.5 * _MainTex_TexelSize.xy * _BlurIntensity;
    vsOutput.uv67.zw = vsInput.uv + float2(-1, 1) * 0.5 * _MainTex_TexelSize.xy * _BlurIntensity;

    return vsOutput;
}

float4 UpSamplePS(PSInput psInput) : SV_TARGET
{
    float4 outputColor = 0.f;

    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv01.xy) * 1/12;
    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv01.zw) * 1/12;
    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv23.xy) * 1/12;
    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv23.zw) * 1/12;

    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv45.xy) * 1/6;
    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv45.zw) * 1/6;
    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv67.xy) * 1/6;
    outputColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv67.zw) * 1/6;

    return outputColor;
}

////////////////////////////////
// 将模糊后的RT与原图叠加
////////////////////////////////
PSInput BloomVS(VSInput vsInput)
{
    PSInput vsOutput;

    vsOutput.positionH = TransformObjectToHClip(vsInput.positionL);
    vsOutput.uv = vsInput.uv;

    return vsOutput;
}

half4 BloomPS(PSInput psInput) : SV_TARGET
{
    half3 outputColor = 0.f;
    
    half4 sourceTex = SAMPLE_TEXTURE2D(_SourceTex, sampler_SourceTex, psInput.uv);
    half4 blurTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, psInput.uv);

    outputColor += sourceTex.rgb + blurTex.rgb * _BloomColor * _BloomIntensity;

    return half4(outputColor, 1.f);
}