#ifndef UNIVERSAL_SURFACE_SHADER_INCLUDED
#define UNIVERSAL_SURFACE_SHADER_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// -------------------------------------
// Surface shader defines
#define SURFACE_SHADER

// NOTE: This is duplicated from LitForwardPass, but we need this to be defined before the Varyings 
// because it determines which fields are defined inside the Varyings. 
#if defined(_PARALLAXMAP)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

// -------------------------------------
// Define the Varyings once, in one central place, to be re-used for both forward and deferred passes
struct Varyings
{
    float2 uv                       : TEXCOORD0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    float3 positionWS               : TEXCOORD1;
#endif

    half3 normalWS                  : TEXCOORD2;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    half4 tangentWS                 : TEXCOORD3;    // xyz: tangent, w: sign
#endif

// How it's defined in LitForwardPass
//#ifdef _ADDITIONAL_LIGHTS_VERTEX
    //half4 fogFactorAndVertexLight   : TEXCOORD5; // x: fogFactor, yzw: vertex light
//#else
    //half  fogFactor                 : TEXCOORD5;
//#endif

// How it's defined in LitGbufferPass
//#ifdef _ADDITIONAL_LIGHTS_VERTEX
    //half3 vertexLighting            : TEXCOORD4;    // xyz: vertex lighting
//#endif

// This is me trying to consolidate them. This will presumably cause errors if _ADDITIONAL_LIGHTS_VERTEX is ever on ;_;
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half4 fogFactorAndVertexLight   : TEXCOORD4; // x: fogFactor, yzw: vertex light
#else
    half  fogFactor                 : TEXCOORD4;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD5;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS                 : TEXCOORD6;
#endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
#ifdef DYNAMICLIGHTMAP_ON
    float2  dynamicLightmapUV       : TEXCOORD8; // Dynamic lightmap UVs
#endif

#ifdef USE_APV_PROBE_OCCLUSION
    float4 probeOcclusion           : TEXCOORD9;
#endif

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// -------------------------------------
// CUSTOM: Forward declaration of SurfaceFunction. This function must be implemented in the shader
void SurfaceFunction(Varyings IN, inout SurfaceData surfaceData);

#endif // UNIVERSAL_SURFACE_SHADER_INCLUDED
