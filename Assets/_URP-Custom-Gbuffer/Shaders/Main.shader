Shader "Universal Render Pipeline/Custom/Main"
{
    // NOTE: This shader is a modified version of the Custom Lit Physically Based Shader code by Felipe Lira from Unity:
    // https://github.com/phi-lira/UniversalShaderExamples/tree/master/Assets/_ExampleScenes/51_LitPhysicallyBased
    
    // Where possible it avoids having to write code twice by declaring a function that specifies the surface properties
    // which are then integrated into the actual fragment function. HMMMM, SOUNDS AWFULLY FAMILIAR
    // Why were surface functions removed from URP again o_0 ?
    
    // This repository also seem interesting (haven't tried it yet):
    // https://github.com/ColinLeung-NiloCat/UnityURP-SurfaceShaderSolution

    // TODO: I need to support custom shader inspector for this to hide
    // scale/offset for normal map using NoScaleOffset.
    Properties
    {
        [Header(Surface)]
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        
        [MainColor] _Custom0("Custom Data 0", Color) = (0, 0, 0, 0)

        // TODO: Pack the following into a half4 and add support to mask map
        // splitting now as I've not implemented custom shader editor yet and
        // this will make it look nices in the UI
        _Metallic("Metallic", Range(0, 1)) = 1.0
        [NoScaleOffset]_MetallicSmoothnessMap("MetalicMap", 2D) = "white" {}
        _OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1.0
        [NoScaleOffset]_AmbientOcclusionMap("AmbientOcclusionMap", 2D) = "white" {}
        _Reflectance("Reflectance for dieletrics", Range(0.0, 1.0)) = 0.5
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5

        [Toggle(_NORMALMAP)] _EnableNormalMap("Enable Normal Map", Float) = 0.0
        [Normal][NoScaleOffset]_BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Map Scale", Float) = 1.0

        [Header(Emission)]
        [HDR]_Emission("Emission Color", Color) = (0,0,0,1)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType" = "Opaque"
            "UniversalMaterialType" = "Lit"
            "Queue"="Geometry"
            "IgnoreProjector" = "True"
        }
        LOD 300
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
        #include "Assets/ShaderLibrary/SurfaceShader.hlsl"
        
        // -------------------------------------
        // Material Keywords
        #pragma shader_feature_local _NORMALMAP
        #pragma shader_feature_local_fragment _ALPHATEST_ON
        //#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
        #pragma shader_feature_local_fragment _EMISSION
        #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
        #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        #pragma shader_feature_local_fragment _OCCLUSIONMAP
        #pragma shader_feature_local _PARALLAXMAP
        #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

        #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
        #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
        #pragma shader_feature_local_fragment _SPECULAR_SETUP
        #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
        
        // -------------------------------------
        // Universal Pipeline keywords
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
        #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
        #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
        #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
        #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
        #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
        
        // -------------------------------------
        // Unity defined keywords
        #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
        #pragma multi_compile _ SHADOWS_SHADOWMASK
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile _ DYNAMICLIGHTMAP_ON
        #pragma multi_compile _ USE_LEGACY_LIGHTMAPS
        #pragma multi_compile _ LOD_FADE_CROSSFADE
        #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
        #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ProbeVolumeVariants.hlsl"
        
        //--------------------------------------
        // GPU Instancing
        #pragma multi_compile_instancing
        #pragma instancing_options renderinglayer
        #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

        // -------------------------------------
        // Material variables.
        // NOTE: I can't call the cbuffer UnityPerMaterial because that is already declared in LitInput.HLSL.
        // This supposedly breaks SRP batching, but I'm not sure what to do about it
        // https://docs.unity3d.com/6000.0/Documentation/Manual/urp/shaders-in-universalrp-srp-batcher.html
        CBUFFER_START(MainCBuffer)
            float4 _Custom0;
        CBUFFER_END
        
        half4 _Emission;
        
        // -------------------------------------
        // NOTE: _BaseMap, _NormalMap are already declared in Unity's code.
        TEXTURE2D(_MetallicSmoothnessMap);
        TEXTURE2D(_AmbientOcclusionMap);

        void SurfaceFunction(Varyings IN, inout SurfaceData surfaceData)
        {
            float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
            
            half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).rgb * _BaseColor.rgb;
            surfaceData.albedo = baseColor;
            
            half4 metallicSmoothness = SAMPLE_TEXTURE2D(_MetallicSmoothnessMap, sampler_BaseMap, uv);
            half metallic = _Metallic * metallicSmoothness.r;
            surfaceData.metallic = metallic;
            surfaceData.smoothness = _Smoothness * metallicSmoothness.a;
            
            surfaceData.occlusion = SAMPLE_TEXTURE2D(_AmbientOcclusionMap, sampler_BaseMap, uv).g * _OcclusionStrength;
            
            #ifdef _NORMALMAP
                surfaceData.normalTS = SampleNormal(IN.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
            #endif
            
            surfaceData.custom0 = _Custom0;
            
            surfaceData.emission += _Emission.rgb;
        }
        
        ENDHLSL

        Pass
        {
            Name "Universal Forward"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            
            // -------------------------------------
            // Shader Stages
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            
            // -------------------------------------
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
            
            ENDHLSL
        }
        
        Pass
        {
            Name "GBuffer"
            Tags { "LightMode" = "UniversalGBuffer" }
            
            // -------------------------------------
            // Render State Commands
            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5

            // Deferred Rendering Path does not support the OpenGL-based graphics API:
            // Desktop OpenGL, OpenGL ES 3.0, WebGL 2.0.
            #pragma exclude_renderers gles3 glcore
            
            // -------------------------------------
            // Shader Stages
            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment
            
            // -------------------------------------
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitGBufferPass.hlsl"
            
            ENDHLSL
        }

        // TODO: This is currently breaking SRP batcher as these passes are including
        //  a different cbuffer. We need to fix it in URP side.
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
        UsePass "Universal Render Pipeline/Lit/Meta"
    }
}
