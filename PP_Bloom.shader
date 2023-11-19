Shader "Custom/PP_Bloom"
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
        #include "Assets/Shader/PostProcess/Bloom.hlsl"
        
        ENDHLSL

        Pass
        {
            Name "Extract Luminanice"
            
            HLSLPROGRAM

            #pragma vertex ExtractLumVS
            #pragma fragment ExtractLumPS
            
            ENDHLSL
            
        }

        Pass
        {
            NAME "Down Sample"
            
            HLSLPROGRAM

            #pragma vertex DownSampleVS
            #pragma fragment DownSamplePS
            
            ENDHLSL
        }

        Pass
        {
            NAME "Up Sample"
            
            HLSLPROGRAM

            #pragma vertex UpSampleVS
            #pragma fragment UpSamplePS
            
            ENDHLSL
        }

        Pass
        {
            Name "add blur with source RT"
            
            HLSLPROGRAM
            #pragma vertex BloomVS
            #pragma fragment BloomPS
            ENDHLSL
        }
    }
}
