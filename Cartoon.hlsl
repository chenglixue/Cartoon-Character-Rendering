#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// -------------------------------------------- variable definition --------------------------------------------

CBUFFER_START(UnityPerMaterial)
float4 _DiffuseMap_ST;
half4 _DiffuseTint;

half4 _FaceShadowColor;
float _LerpFaceShadow;

float4 _RampMap_ST;
float _RampShadowRang;
half4 _RampHairColorTint1;

half _Enable_Specular;
half4 _SpecularColor;
float4 _SpecularIntensityLayer;
float4 _SpecularRangeLayer;
float _HairSpecularRange;
float _ViewSpecularRange;
float _HairSpecularIntensity;
float3 _HairSpecularColor;
        
float _MetalMapV;
float _MetalMapIntensity;
float _ShinnessMetal; 
float _SpecularIntensityMetal;

float _RimLightUVOffsetMul;
float _RimLightThreshold;
half4 _RimLightColor;

float _OutlineWidth;
half4 _OutlineColor;

float _EmissionIntensity;

CBUFFER_END

float DayOrLight;   // 根据角度判断夜晚还是白天
TEXTURE2D(_DiffuseMap);                 SAMPLER(sampler_DiffuseMap);
TEXTURE2D(_RampMap);                    SAMPLER(sampler_RampMap);
TEXTURE2D(_LightMap);                   SAMPLER(sampler_LightMap);
TEXTURE2D(_MetalMap);                   SAMPLER(sampler_MetalMap);
TEXTURE2D(_FaceMap);                    SAMPLER(sampler_FaceMap);
TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);   //深度图

struct VSInput
{
    float4 positionL : POSITION;
    float4 normalL : NORMAL;
    float4 tangentL : TANGENT;
    float4 color : COLOR0;
    float2 uv : TEXCOORD0;
};

struct PSInput
{
    float4 positionH : SV_POSITION;
    float4 positionNDC : TEXCOORD6;
    float4 normalW : NORMAL;
    float4 tangentW : TANGENT;
    float4 shadowUV : TEXCOORD1;
    float4 uv : TEXCOORD2;
    float3 viewDirW : TEXCOORD3;
    float3 positionV : TEXCOORD4;
    float3 positionW : TEXCOORD5;
};

// -------------------------------------------- function definition --------------------------------------------

float4 TransformHClipToViewPort(float4 positionH)
{
    float4 output = positionH * 0.5f;
    output.xy = float2(output.x, output.y * _ProjectionParams.x) + output.w;
    output.zw = positionH.zw;

    return output / output.w;
}

PSInput ToonPassVS(VSInput vsInput)
{
    PSInput vsOutput;

    const VertexPositionInputs vertexPositionInput = GetVertexPositionInputs(vsInput.positionL);
    const VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(vsInput.normalL, vsInput.tangentL);

    vsOutput.positionH = vertexPositionInput.positionCS;
    vsOutput.positionW = vertexPositionInput.positionWS;
    vsOutput.positionV = vertexPositionInput.positionVS;
    vsOutput.positionNDC = vertexPositionInput.positionNDC;
    
    vsOutput.normalW.xyz = vertexNormalInput.normalWS;
    vsOutput.viewDirW = GetCameraPositionWS() - vsOutput.positionW;

    vsOutput.uv.xy = TRANSFORM_TEX(vsInput.uv, _DiffuseMap);

    return vsOutput;
}


half4 ToonPassPS(PSInput psInput) : SV_TARGET
{
    half3 outputColor = 0.f;

    float3 positionW = psInput.positionW;
    float3 positionV = psInput.positionV;
    float4 positionH = psInput.positionH;
    float4 positionNDC = psInput.positionNDC;
    
    float3 normalW = normalize(psInput.normalW);
    float3 viewDirW = normalize(psInput.viewDirW);
    
    Light mainLight = GetMainLight();
    float3 mainLightDirW = normalize(mainLight.direction);
    half3 mainLightColor = mainLight.color;
    half3 halfDirW = normalize(viewDirW + mainLightDirW);

    #if defined UNITY_UV_STARTS_AT_TOP
    psInput.uv.y = psInput.uv.y < 0.f ? 1 - psInput.uv.y : psInput.uv.y;
    #endif

    // 判断明暗
    half rampValue = 0.f;
    float NoL = saturate(dot(normalW, mainLightDirW)) * 0.5 + 0.5;
    float NoH = saturate(dot(normalW, halfDirW));
    float NoV = saturate(dot(normalW, viewDirW));
    DayOrLight = atan2(mainLightDirW.y, mainLightDirW.x);

    half4 diffuseTex = SAMPLE_TEXTURE2D(_DiffuseMap, sampler_DiffuseMap, psInput.uv.xy) * _DiffuseTint;
    half4 lightMapTex = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, psInput.uv.xy);
    half4 metalTex = SAMPLE_TEXTURE2D(_MetalMap, sampler_MetalMap, mul(UNITY_MATRIX_V, normalW).xy).r;  // 金属高光始终随相机移动
    metalTex = saturate(metalTex);
    metalTex = step(_MetalMapV, metalTex) * _MetalMapIntensity;  // 控制metal强度和范围
    
    ////////////////////////////////
    // Ramp
    ////////////////////////////////
    #if defined ENABLE_SHADOW_RAMP
    // 防止采样边缘时出现黑线
    float rampU = NoL * (1 / _RampShadowRang - 0.003);
    float rampVOffset = DayOrLight > PI / 4 && DayOrLight < 3/4 * PI ? 0.5 : 0.f;   // 白天采样上面，夜晚采样下面
    float rampLayer = lightMapTex.a;    // ramp分层
                
    // 从上向下采样
    half3 shadowRamp1 = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampU, 0.45 + rampVOffset));
    half3 shadowRamp2 = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampU, 0.35 + rampVOffset));
    half3 shadowRamp3 = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampU, 0.25 + rampVOffset));
    half3 shadowRamp4 = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampU, 0.15 + rampVOffset));
    half3 shadowRamp5 = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampU, 0.05 + rampVOffset));

    /*
	0.0：hard/emission/silk/hair
	0.0 - 0.3：soft/common
	0.3 - 0.5：metal
	0.5 - 0.7：皮肤
	1.0：布料
	*/
    half3 frabicRamp = shadowRamp5 * step(abs(rampLayer - 1.f), 0.05);
    half3 skinRamp = shadowRamp1 * step(abs(rampLayer - 0.7f), 0.05);
    half3 metalRamp = shadowRamp3 * step(abs(rampLayer - 0.5f), 0.05);
    half3 softRamp = shadowRamp4 * step(abs(rampLayer - 0.3f), 0.05);
    half3 hardRamp = shadowRamp5 * step(abs(rampLayer - 0.0f), 0.05) * _RampHairColorTint1.rgb;

    half3 finalRamp = frabicRamp + skinRamp + metalRamp + softRamp + hardRamp;

    rampValue = step(_RampShadowRang, NoL);
    half3 rampShadowColor = lerp(finalRamp * diffuseTex.rgb, diffuseTex.rgb, rampValue);
    
    outputColor += rampShadowColor;
        
    #endif

    ////////////////////////////////
    // 高光
    ////////////////////////////////
    #if defined ENABLE_SPECULAR
    half3 specular = 0.f;
    half3 stepSpecular1 = 0.f;
    half3 stepSpecular2 = 0.f;
    float specularLayer = lightMapTex.r * 255;  // 数值更精确
    float stepSpecularMask = lightMapTex.b;
    if(specularLayer > 0 && specularLayer < 50)
    {
        stepSpecular1  = step(1 - _SpecularRangeLayer.x, NoH) * _SpecularIntensityLayer.x;
        #if defined ENABLE_SPECULAR_INTENISTY_MASK1
        stepSpecular1  *= stepSpecularMask;  // 根据效果决定是否启用specular mask
        #endif
        stepSpecular1 *= diffuseTex.rgb;
    }
    
    if(specularLayer > 50 && specularLayer < 150)
    {
        stepSpecular1 = step(1 - _SpecularRangeLayer.y, NoH) * _SpecularIntensityLayer.y;
        #if defined ENABLE_SPECULAR_INTENISTY_MASK2
        stepSpecular1 *= stepSpecularMask;
        #endif
        stepSpecular1 *= diffuseTex.rgb;
    }

    // 头发高光
    if(specularLayer > 150 && specularLayer < 200)
    {
        #if defined _ENABLE_SPECULAR_HAIR
        // 除开头发的高光
        stepSpecular1 = step(1 - _SpecularRangeLayer.w, NoH) * _SpecularIntensityLayer.w;
        stepSpecular1 = lerp(stepSpecular1, 0, stepSpecularMask);
        stepSpecular1 *= diffuseTex.rgb;

        // 头发的高光
        stepSpecular2 = step(1 - _SpecularRangeLayer.w, NoH) * _SpecularIntensityLayer.w;
        #ifdef ENABLE_SPECULAR_INTENISTY_MASK4
        stepSpecular2 *= stepSpecularMask;
        #endif
        stepSpecular2 *= diffuseTex.rgb;

        // body 高光
        #else
        stepSpecular1  = step(1 - _SpecularRangeLayer.w, NoH) * _SpecularIntensityLayer.w;
        #if defined ENABLE_SPECULAR_INTENISTY_MASK3
        stepSpecular1  *= stepSpecularMask;
        #endif
        stepSpecular1 *= diffuseTex.rgb;
        
        #endif
    }

    // 金属
    if(specularLayer >= 200 && specularLayer < 260)
    {
        specular = pow(NoH, _ShinnessMetal) * _SpecularIntensityMetal;
        #if defined ENABLE_SPECULAR_INTENISTY_MASK5
        specular *= stepSpecularMask;
        #endif
        specular += metalTex.rgb;
        specular *= diffuseTex.rgb;
    }
    
    float specularRange = step(1 - _HairSpecularRange, NoH);
    float viewRange = step(1 - _ViewSpecularRange, NoV);
    half3 hairSpecular = specularRange * viewRange * stepSpecular2 * _HairSpecularIntensity;
    hairSpecular *= diffuseTex.rgb * _HairSpecularColor;
    
    specular = lerp(stepSpecular1, specular, lightMapTex.r);
    specular = lerp(0, specular, lightMapTex.r);
    specular = lerp(0, specular, rampValue);

    outputColor += specular + hairSpecular;
    #endif

    ////////////////////////////////
    // 边缘光
    ////////////////////////////////

    #if defined ENABLE_RIMLIGHT

    half3 rimLight = 0.f;
    
    float3 normalV = normalize(mul((float3x3)UNITY_MATRIX_V, normalW));
    // 在view space进行偏移(z不能变化，因为HClip space下的w = view space下的-z,必须一致才能变换到正确的viewport)
    float3 offsetPosV = float3(positionV.xy + normalV.xy * _RimLightUVOffsetMul, positionV.z);

    // 偏移后需要将其转换到viewport下
    float4 offsetPosH = TransformWViewToHClip(offsetPosV);
    float4 offsetPosVP = TransformHClipToViewPort(offsetPosH);
    
    float depth = positionNDC.z / positionNDC.w;
    float offsetDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, offsetPosVP).r;
    float linearDepth = LinearEyeDepth(depth, _ZBufferParams);  // depth转换为线性
    float linearOffsetDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);  // 偏移后的
    float depthDiff = linearOffsetDepth - linearDepth;
    float rimLightMask = step(_RimLightThreshold * 0.1, depthDiff);

    rimLight = _RimLightColor.rgb * _RimLightColor.a * rimLightMask;

    outputColor += rimLight;
    #endif

    ////////////////////////////////
    // 面部阴影
    ////////////////////////////////
    #if defined ENABLE_FACE_SHAODW
    half3 faceColor = diffuseTex;
    float isShadow = 0;
    // 对应灯光从模型正前到左后
    half4 l_FaceTex = SAMPLE_TEXTURE2D(_FaceMap, sampler_FaceMap, psInput.uv.xy);
    // 对应灯光从模型正前到右后
    half4 r_FaceTex = SAMPLE_TEXTURE2D(_FaceMap, sampler_FaceMap, float2(1 - psInput.uv.x, psInput.uv.y));

    float2 leftDir = normalize(TransformObjectToWorldDir(float3(-1, 0, 0)).xz);  // 模型正左
    float2 frontDir = normalize(TransformObjectToWorldDir(float3(0, 0, 1)).xz); // 模型正前
    float angleDiff = 1 - saturate(dot(frontDir, mainLightDirW.xz) * 0.5 + 0.5);    // 前向和灯光的角度差
    float ilm = dot(mainLightDirW.xz, leftDir) > 0 ? l_FaceTex.r : r_FaceTex.r;     // 确定facetex

    // 角度差和SDF阈值进行判断
    isShadow = step(ilm, angleDiff);
    float bias = smoothstep(0, _LerpFaceShadow, abs(angleDiff - ilm));  // 阴影边界平滑，否则会出现锯齿
    if(angleDiff > 0.99 || isShadow == 1) faceColor = lerp(diffuseTex, diffuseTex * _FaceShadowColor.rgb, bias);
    outputColor += faceColor;
    #endif

    ////////////////////////////////
    // 自发光
    ////////////////////////////////
    half3 emission = 0.f;
    #if defined ENABLE_EMISSION
    emission = diffuseTex.rgb * diffuseTex.a * _EmissionIntensity;
    #endif
    outputColor += emission;
    
    outputColor *= mainLightColor;
    outputColor += half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
    
    return half4(outputColor, 1.f);
}

PSInput OutlineVS(VSInput vsInput)
{
    PSInput vsOutput;

    vsOutput.positionH = TransformObjectToHClip(vsInput.positionL);

    float4 scaledSSParam = GetScaledScreenParams();
    float scaleSS = abs(scaledSSParam.x / scaledSSParam.y); // 屏幕宽高比
    vsOutput.normalW.xyz = TransformObjectToWorldNormal(vsInput.normalL);
    float3 normalH = TransformWorldToHClipDir(vsOutput.normalW.xyz);
    float2 extendWidth = normalize(normalH.xy) * _OutlineWidth * 0.01;
    extendWidth.x /= scaleSS;   // 宽高比可能不是1，需要将其变为1，消除影响
                
    #if defined OUTLINE_FIXED
    // 描边宽度固定
    vsOutput.positionH.xy += extendWidth * vsOutput.positionH.w;    // 变换至NDC空间(因为NDC空间是标准化空间，距离是固定的)
                
    #else
    // 描边宽度随相机到物体的距离变化
    vsOutput.positionH.xy += extendWidth;
            
    #endif

    return vsOutput;
}

half4 OutlinePS(PSInput psInput) : SV_TARGET
{
    return _OutlineColor;
}

