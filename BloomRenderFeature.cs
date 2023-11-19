using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class BloomRenderFeature : ScriptableRendererFeature
{
    // render feature 显示内容
    [System.Serializable]
    public class PassSetting
    {
        [Tooltip("profiler tag will show up in frame debugger")]
        public readonly string m_ProfilerTag = "Bloom Pass";
        [Tooltip("Pass安插位置")]
        public RenderPassEvent m_passEvent = RenderPassEvent.AfterRenderingTransparents;
        
        [Tooltip("降低分辨率")]
        [Range(1, 5)] 
        public int m_Downsample = 1;

        [Tooltip("模糊迭代次数")]
        [Range(1, 5)] 
        public int m_PassLoop = 2;
        
        [Tooltip("模糊强度")]
        [Range(0, 10)] 
        public float m_BlurIntensity = 1;
        
        [Tooltip("亮度阈值")]
        [Range(0, 1)]
        public float m_LuminanceThreshold = 0.5f;
        
        [Tooltip("Bloom颜色")]
        public Color m_BloomColor = new Color(1.0f, 1.0f, 1.0f, 1.0f);
        
        [Tooltip("Bloom强度")]
        [Range(0, 10)]
        public float m_BloomIntensity = 1;
    }
    
    class BloomRenderPass : ScriptableRenderPass
    {
        // 用于存储pass setting
        private BloomRenderFeature.PassSetting m_passSetting;

        private RenderTargetIdentifier m_TargetBuffer, m_TempBuffer;

        private Material m_Material;

        static class ShaderIDs
        {
            // int 相较于 string可以获得更好的性能，因为这是预处理的
            internal static readonly int m_BlurIntensityProperty = Shader.PropertyToID("_BlurIntensity");
            internal static readonly int m_LuminanceThresholdProperty = Shader.PropertyToID("_LuminanceThreshold");
            internal static readonly int m_BloomColorProperty = Shader.PropertyToID("_BloomColor");
            internal static readonly int m_BloomIntensityProperty = Shader.PropertyToID("_BloomIntensity");
            
            internal static readonly int m_TempBufferProperty = Shader.PropertyToID("_BufferRT1");
            internal static readonly int m_SourceBufferProperty = Shader.PropertyToID("_SourceTex");
        }

        // 降采样和升采样的ShaderID
        struct BlurLevelShaderIDs
        {
            internal int downLevelID;
            internal int upLevelID;
        }
        static int maxBlurLevel = 16;
        private BlurLevelShaderIDs[] blurLevel;

        // 用于设置material 属性
        public BloomRenderPass(BloomRenderFeature.PassSetting passSetting)
        {
            this.m_passSetting = passSetting;

            renderPassEvent = m_passSetting.m_passEvent;

            if (m_Material == null) m_Material = CoreUtils.CreateEngineMaterial("Custom/PP_Bloom");
            
            // 基于pass setting设置material Properties
            m_Material.SetFloat(ShaderIDs.m_BlurIntensityProperty, m_passSetting.m_BlurIntensity);
            m_Material.SetFloat(ShaderIDs.m_LuminanceThresholdProperty, m_passSetting.m_LuminanceThreshold);
            m_Material.SetColor(ShaderIDs.m_BloomColorProperty, m_passSetting.m_BloomColor);
            m_Material.SetFloat(ShaderIDs.m_BloomIntensityProperty, m_passSetting.m_BloomIntensity);
        }
        
        // Gets called by the renderer before executing the pass.
        // Can be used to configure render targets and their clearing state.
        // Can be used to create temporary render target textures.
        // If this method is not overriden, the render pass will render to the active camera render target.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // Grab the color buffer from the renderer camera color target
            m_TargetBuffer = renderingData.cameraData.renderer.cameraColorTarget;

            blurLevel = new BlurLevelShaderIDs[maxBlurLevel];
            for (int t = 0; t < maxBlurLevel; ++t)  // 16个down level id, 16个up level id
            {
                blurLevel[t] = new BlurLevelShaderIDs
                {
                    downLevelID = Shader.PropertyToID("_BlurMipDown" + t),
                    upLevelID = Shader.PropertyToID("_BlurMipUp" + t)
                };
            }
        }

        // The actual execution of the pass. This is where custom rendering occurs
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // Grab a command buffer. We put the actual execution of the pass inside of a profiling scope
            CommandBuffer cmd = CommandBufferPool.Get();
            
            // camera target descriptor will be used when creating a temporary render texture
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
            // 设置 temporary render texture的depth buffer的精度
            descriptor.depthBufferBits = 0;

            using (new ProfilingScope(cmd, new ProfilingSampler(m_passSetting.m_ProfilerTag)))
            {
                // 初始图像作为down的初始图像
                RenderTargetIdentifier lastDown = m_TargetBuffer;
                cmd.GetTemporaryRT(ShaderIDs.m_SourceBufferProperty, descriptor, FilterMode.Bilinear);
                cmd.CopyTexture(m_TargetBuffer, ShaderIDs.m_SourceBufferProperty);  // 将原RT复制给_SourceTex
                ////////////////////////////////
                // 提取亮度开始
                ////////////////////////////////
                cmd.GetTemporaryRT(ShaderIDs.m_TempBufferProperty, descriptor, FilterMode.Bilinear);
                m_TempBuffer = new RenderTargetIdentifier(ShaderIDs.m_TempBufferProperty);
                cmd.Blit(m_TargetBuffer, m_TempBuffer, m_Material, 0);
                cmd.Blit(m_TempBuffer, lastDown);
                ////////////////////////////////
                // 提取亮度结束
                ////////////////////////////////
                
                ////////////////////////////////
                // 模糊开始
                ////////////////////////////////
                // 降采样
                descriptor.width /= m_passSetting.m_Downsample;
                descriptor.height /= m_passSetting.m_Downsample;
                // 计算down sample
                for (int i = 0; i < m_passSetting.m_PassLoop; ++i)
                {
                    // 创建down、up的Temp RT
                    int midDown = blurLevel[i].downLevelID;
                    int midUp = blurLevel[i].upLevelID;
                    cmd.GetTemporaryRT(midDown, descriptor, FilterMode.Bilinear);
                    cmd.GetTemporaryRT(midUp, descriptor, FilterMode.Bilinear);
                    // down sample
                    cmd.Blit(lastDown, midDown, m_Material, 1);
                    // 计算得到的图像复制给lastDown，以便下个循环继续计算
                    lastDown = midDown;
                    
                    // down sample每次循环都降低分辨率
                    descriptor.width = Mathf.Max(descriptor.width / 2, 1);
                    descriptor.height = Mathf.Max(descriptor.height / 2, 1);
                }
                
                // 计算up sample
                // 将最终的down sample RT ID赋值给首个up sample RT ID
                int lastUp = blurLevel[m_passSetting.m_PassLoop - 1].downLevelID;
                // 第一个ID已经赋值
                for (int i = m_passSetting.m_PassLoop - 2; i > 0; --i)
                {
                    int midUp = blurLevel[i].upLevelID;
                    cmd.Blit(lastUp, midUp, m_Material, 2);
                    lastUp = midUp;
                }
                // 将最终的up sample RT 复制给 lastDown
                cmd.Blit( lastUp, m_TargetBuffer, m_Material, 2);
                ////////////////////////////////
                // 模糊结束
                ////////////////////////////////
                
                ////////////////////////////////
                // 模糊原图叠加开始
                ////////////////////////////////
                cmd.Blit(m_TargetBuffer, m_TempBuffer, m_Material, 3);
                cmd.Blit(m_TempBuffer, m_TargetBuffer);
                ////////////////////////////////
                // 模糊原图叠加结束
                ////////////////////////////////
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
            for (int i = 0; i < m_passSetting.m_PassLoop; ++i)
            {
                cmd.ReleaseTemporaryRT(blurLevel[i].downLevelID);
                cmd.ReleaseTemporaryRT(blurLevel[i].upLevelID);
            }
            
            cmd.ReleaseTemporaryRT(ShaderIDs.m_TempBufferProperty);
        }
    }

    public PassSetting m_Setting = new PassSetting();
    BloomRenderPass m_DualBlurPass;
    
    // 初始化
    public override void Create()
    {
        m_DualBlurPass = new BloomRenderPass(m_Setting);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // can queue up multiple passes after each other
        renderer.EnqueuePass(m_DualBlurPass);
    }
}


