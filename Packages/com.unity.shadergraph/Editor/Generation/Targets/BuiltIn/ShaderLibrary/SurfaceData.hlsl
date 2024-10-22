#ifndef BUILTIN_SURFACE_DATA_INCLUDED
#define BUILTIN_SURFACE_DATA_INCLUDED

// Must match BuiltIn ShaderGraph master node
struct SurfaceData
{
    half3 albedo;
    half3 specular;
    half  metallic;
    half  smoothness;
    half3 normalTS;
    half3 emission;
    half  occlusion;
    half  alpha;
    half  clearCoatMask;
    half  clearCoatSmoothness;
    half4 custom0; // CUSTOM: Data that goes into the extra gbuffer. You can also split this up into separate fields.
};

#endif
