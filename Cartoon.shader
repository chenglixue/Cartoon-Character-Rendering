Shader "Custom/Cartoon"
{
    Properties
    {
        [Header(Diffuse Setting)]
        [Space(3)]
        [MainTexture]_DiffuseMap("Diffuse Texture", 2D) = "white" {}
        [HDR][MainColor]_DiffuseTint("Diffuse Color Tint", Color) = (1, 1, 1, 1)
        [Space(30)]
        
        [Header(Shadow Setting)]
        [Space(3)]
        _LightMap("LightMap", 2D) = "black" {}
        [Space(20)]
        
        [Header(Face Shadow Setting)]
        [Space(3)]
        [Toggle(ENABLE_FACE_SHAODW)] _EnableFaceShadow("Enable Face Shadow", Int) = 1
        _FaceMap("Face Map", 2D) = "white" {}
        [HDR]_FaceShadowColor("Face Shadow Color", Color) = (1, 1, 1, 1)
        _LerpFaceShadow("Lerp Face Shadow", Range(0, 1)) = 1
        [Space(30)]
        
        [Header(Shadow Ramp Setting)]
        [Space(3)]
        [Toggle(ENABLE_SHADOW_RAMP)]_EnableShadowRamp("Enable Shadow Ramp", Int) = 1
        _RampMap("Ramp Texture", 2D) = "white" {}
        _RampShadowRang("Ramp Shadow Range", Range(0, 1)) = 0.5
        [HDR]_RampHairColorTint1("Hair Color Tint 1", Color) = (1, 1, 1, 1)
        [Space(30)]
        
        [Header(Specular Setting)]
        [Space(3)]
        [Toggle(ENABLE_SPECULAR)] _Enable_Specular("Enable Specular", Int) = 1
        [HDR]_SpecularColor("Specular Color", Color) = (0.8, 0.8, 0.8, 1)
        _SpecularIntensityLayer("Specular Layer Intensity", Vector) = (1, 1, 1, 1)  // 每层的高光强度
        _SpecularRangeLayer("Specular Layer Range", Vector) = (1, 1, 1, 1)  // 用于分离高光的明部和暗部
        [Toggle(ENABLE_SPECULAR_INTENISTY_MASK1)] _Enable_Specular_Intensity_Mask1("Enable Specular Intensity Mask 1", Int) = 1
        [Toggle(ENABLE_SPECULAR_INTENISTY_MASK2)] _Enable_Specular_Intensity_Mask2("Enable Specular Intensity Mask 2", Int) = 1
        [Toggle(ENABLE_SPECULAR_INTENISTY_MASK3)] _Enable_Specular_Intensity_Mask3("Enable Specular Intensity Mask 3", Int) = 1
        [Toggle(ENABLE_SPECULAR_INTENISTY_MASK4)] _Enable_Specular_Intensity_Mask4("Enable Specular Intensity Mask 4", Int) = 1
        [Toggle(ENABLE_SPECULAR_INTENISTY_MASK5)] _Enable_Specular_Intensity_Mask5("Enable Specular Intensity Mask 5", Int) = 1
        
        [KeywordEnum(BODY, HAIR)] _ENABLE_SPECULAR("Enable specular body or hair?", Int) = 1
        _HairSpecularRange("Hair Specular Range", Range(0, 1)) = 1  // 控制高光范围
        _ViewSpecularRange("View Specular Range", Range(0, 1)) = 1  // 控制视角对高光的影响
        _HairSpecularIntensity("Hair Specular Intensity", float) = 10
        [HDR]_HairSpecularColor("Hair Specular Color", Color) = (1, 1, 1, 1)
        
        _MetalMap("Metal Map", 2D) = "black" {}
        _MetalMapV("Metal Map V", Range(0, 1)) = 1
        _MetalMapIntensity("Metal Map Intensity", Range(0, 1)) = 1
        _SpecularIntensityMetal("Specular Layer Metal", Float) = 1
        _ShinnessMetal("Specular Metal Shinness", Range(5, 30)) = 5
        [Space(30)]
        
        [Header(RimLight)]
        [Space(3)]
        [Toggle(ENABLE_RIMLIGHT)] _Enable_RimLight("Enable RimLight", Int) = 1
        _RimLightUVOffsetMul("Rim Light Width", Range(0, 0.1)) = 0.1
        _RimLightThreshold("Rim Light Threshold", Range(0, 1)) = 0.5
        [HDR]_RimLightColor("Rim Light Color", Color) = (1, 1, 1, 1)
        [Space(30)]
        
        [Header(Outline)]
        [Space(3)]
        [Toggle(OUTLINE_FIXED)] _Outline_Fixed("Outline Fixed", Int) = 1
        _OutlineWidth("Outline Width", Range(0, 1)) = 1
        [HDR]_OutlineColor("Outline Color", Color) = (1, 1, 1, 1)
        
        [Header(Emission)]
        [Space(3)]
        [Toggle(ENABLE_EMISSION)] _Enable_Emission("Enable Emission", Int) = 1
        _EmissionIntensity("Emission Intensity", Range(0, 5)) = 1
    }
    
    SubShader
    {
        Tags
        {
            "Pipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }
        
        HLSLINCLUDE

        ENDHLSL

// ------------------------------------------------------------------ Toon Main Pass ------------------------------------------------------------------
        Pass
        {
            NAME "Toon Main Pass"
            
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            Cull Back
            
            HLSLPROGRAM
            
            #pragma shader_feature_local ENABLE_SHADOW_RAMP
            #pragma shader_feature_local ENABLE_SPECULAR
            #pragma shader_feature_local ENABLE_SPECULAR_INTENISTY_MASK1
            #pragma shader_feature_local ENABLE_SPECULAR_INTENISTY_MASK2
            #pragma shader_feature_local ENABLE_SPECULAR_INTENISTY_MASK3
            #pragma shader_feature_local ENABLE_SPECULAR_INTENISTY_MASK4
            #pragma shader_feature_local ENABLE_SPECULAR_INTENISTY_MASK4
            #pragma shader_feature_local ENABLE_SPECULAR_INTENISTY_MASK5
            #pragma shader_feature_local _ENABLE_SPECULAR_HAIR _ENABLE_SPECULAR_BODY
            #pragma shader_feature_local ENABLE_FACE_SHAODW
            #pragma shader_feature_local ENABLE_RIMLIGHT
            #pragma shader_feature_local ENABLE_EMISSION

            #include_with_pragmas "Assets/Shader/LingHua/Cartoon.hlsl"
            
            #pragma vertex ToonPassVS
            #pragma fragment ToonPassPS
            
            ENDHLSL
        }

// ------------------------------------------------------------------ Outline Pass ------------------------------------------------------------------
        Pass
        {
            Name "Outline Pass"
            
            Tags
            {
                // URP 中使用多Pass，需要将LightMode设为SRPDefaultUnlit
                "LightMode" = "SRPDefaultUnlit"
            }
            Cull Front
            
            HLSLPROGRAM
            
            #pragma shader_feature_local OUTLINE_FIXED

            #include_with_pragmas "Assets/Shader/LingHua/Cartoon.hlsl"

            #pragma vertex OutlineVS
            #pragma fragment OutlinePS
            
            ENDHLSL
        }


        Pass
        {
            Tags
            {
                "LightMode" = "DepthOnly"
            }
        }
    }
    //FallBack "Diffuse"
}
