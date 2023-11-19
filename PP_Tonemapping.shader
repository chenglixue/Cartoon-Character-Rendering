Shader "Custom/PP_Tonemapping"
{
    Properties
    {
        _MainTex("Main Tex", 2D) = "white" {}
    }
    
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }
        
        Cull Off
        ZWrite Off
        ZTest Always
        
        HLSLINCLUDE
        #include "Assets/Shader/PostProcess/Tonemapping.hlsl"
        ENDHLSL
        
        Pass
        {
            Name "Tone mapping"
            
            HLSLPROGRAM
            #pragma vertex TonemappingVS
            #pragma fragment TonemappingPS
            ENDHLSL
        }
    }
}
