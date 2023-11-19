using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TonemappingRenderFeature : ScriptableRendererFeature
{
    // render feature 显示内容
    [System.Serializable]
    public class PassSetting
    {
        [Tooltip("显示在frame debugger中的标签名")]
        public readonly string m_ProfilerTag = "Tonemapping Pass";
        [Tooltip("安插位置")]
        public RenderPassEvent m_passEvent = RenderPassEvent.AfterRenderingTransparents;

        [Tooltip("最大亮度[1, 100]")]
        [Range(1, 100)]
        public float m_MaxLuminanice = 1f;
        
        [Tooltip("对比度")]
        [Range(1, 5)]
        public float m_Contrast = 1f;
        
        [Tooltip("线性区域的起点")]
        [Range(0, 1)]
        public float m_LinearSectionStart = 0.4f;
        
        [Tooltip("线性区域的长度")]
        [Range(0, 1)]
        public float m_LinearSectionLength = 0.24f;
        
        [Tooltip("Black Tightness C")]
        [Range(0, 3)]
        public float m_BlackTightnessC = 1.33f;
        
        [Tooltip("Black Tightness B")]
        [Range(0, 1)]
        public float m_BlackTightnessB = 0f;
    }
    
    class TonemappingRenderPass : ScriptableRenderPass
    {
        // 用于存储pass setting
        private TonemappingRenderFeature.PassSetting m_passSetting;

        private RenderTargetIdentifier m_TargetBuffer, m_TempBuffer;

        private Material m_Material;

        static class ShaderIDs
        {
            // int 相较于 string可以获得更好的性能，因为这是预处理的
            internal static readonly int m_MaxLuminaniceID = Shader.PropertyToID("_MaxLuminanice");
            internal static readonly int m_ContrastID = Shader.PropertyToID("_Contrast");
            internal static readonly int m_LinearSectionStartID = Shader.PropertyToID("_LinearSectionStart");
            internal static readonly int m_LinearSectionLengthID = Shader.PropertyToID("_LinearSectionLength");
            internal static readonly int m_BlackTightnessCID = Shader.PropertyToID("_BlackTightnessC");
            internal static readonly int m_BlackTightnessBID = Shader.PropertyToID("_BlackTightnessB");
            
            internal static readonly int m_TempBufferID = Shader.PropertyToID("_BufferRT1");
        }

        // 用于设置material 属性
        public TonemappingRenderPass(TonemappingRenderFeature.PassSetting passSetting)
        {
            this.m_passSetting = passSetting;

            renderPassEvent = m_passSetting.m_passEvent;

            if (m_Material == null) m_Material = CoreUtils.CreateEngineMaterial("Custom/PP_Tonemapping");
            
            // 基于pass setting设置material Properties
            m_Material.SetFloat(ShaderIDs.m_MaxLuminaniceID, m_passSetting.m_MaxLuminanice);
            m_Material.SetFloat(ShaderIDs.m_ContrastID, m_passSetting.m_Contrast);
            m_Material.SetFloat(ShaderIDs.m_LinearSectionStartID, m_passSetting.m_LinearSectionStart);
            m_Material.SetFloat(ShaderIDs.m_LinearSectionLengthID, m_passSetting.m_LinearSectionLength);
            m_Material.SetFloat(ShaderIDs.m_BlackTightnessCID, m_passSetting.m_BlackTightnessC);
            m_Material.SetFloat(ShaderIDs.m_BlackTightnessBID, m_passSetting.m_BlackTightnessB);
        }
        
        // Gets called by the renderer before executing the pass.
        // Can be used to configure render targets and their clearing state.
        // Can be used to create temporary render target textures.
        // If this method is not overriden, the render pass will render to the active camera render target.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // camera target descriptor will be used when creating a temporary render texture
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
            // Set the number of depth bits we need for temporary render texture
            descriptor.depthBufferBits = 0;
            
            // Enable these if pass requires access to the CameraDepthTexture or the CameraNormalsTexture.
            // ConfigureInput(ScriptableRenderPassInput.Depth);
            // ConfigureInput(ScriptableRenderPassInput.Normal);
            
            // Grab the color buffer from the renderer camera color target
            m_TargetBuffer = renderingData.cameraData.renderer.cameraColorTarget;
            
            // Create a temporary render texture using the descriptor from above
            cmd.GetTemporaryRT(ShaderIDs.m_TempBufferID, descriptor, FilterMode.Bilinear);
            m_TempBuffer = new RenderTargetIdentifier(ShaderIDs.m_TempBufferID);
        }

        // The actual execution of the pass. This is where custom rendering occurs
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // Grab a command buffer. We put the actual execution of the pass inside of a profiling scope
            CommandBuffer cmd = CommandBufferPool.Get();

            using (new ProfilingScope(cmd, new ProfilingSampler(m_passSetting.m_ProfilerTag)))
            {
                // Blit from the color buffer to a temporary buffer and back
                Blit(cmd, m_TargetBuffer, m_TempBuffer, m_Material, 0);

                Blit(cmd, m_TempBuffer, m_TargetBuffer);
            }
            
            // Execute the command buffer and release it
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        
        // Called when the camera has finished rendering
        // release/cleanup any allocated resources that were created by this pass
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if(cmd == null) throw new ArgumentNullException("cmd");
            
            // Since created a temporary render texture in OnCameraSetup, we need to release the memory here to avoid a leak
            cmd.ReleaseTemporaryRT(ShaderIDs.m_TempBufferID);
        }
    }

    public PassSetting m_Setting = new PassSetting();
    TonemappingRenderPass m_KawaseBlurPass;
    
    // 初始化
    public override void Create()
    {
        m_KawaseBlurPass = new TonemappingRenderPass(m_Setting);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // can queue up multiple passes after each other
        renderer.EnqueuePass(m_KawaseBlurPass);
    }
}


