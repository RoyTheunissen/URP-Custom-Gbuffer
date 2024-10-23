 [![Roy Theunissen](Assets/Documentation~/Github%20Header.jpg)](http://roytheunissen.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE.md)
![GitHub Follow](https://img.shields.io/github/followers/RoyTheunissen?label=RoyTheunissen&style=social) ![Twitter](https://img.shields.io/twitter/follow/Roy_Theunissen?style=social)

_For people who have need of an extra gbuffer but don't want to write their own SRP from scratch_

[Unity Discussions post](https://discussions.unity.com/t/adding-a-gbuffer-to-urp-example-project/1541024)

## About the Project

Do you intend to do a sophisticated lighting effect and need an extra field in the Surface Data? Well, for that to work in the Deferred Rendering path, that extra field then needs to be written to a [Gbuffer](https://en.wikipedia.org/wiki/Deferred_shading), but all the [existing ones](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@13.1/manual/rendering/deferred-rendering-path.html) are basically full already, so you'd need to add your own.

In the [Built-in Render Pipeline](https://docs.unity3d.com/Manual/built-in-render-pipeline.html) this would be a dead end. There is simply no way to make the existing object render passes [also output some of their data to a new gbuffer](https://en.wikipedia.org/wiki/Multiple_Render_Targets). The best you could do is use a [Command Buffer](https://docs.unity3d.com/ScriptReference/Rendering.CommandBuffer.html) and [Shader Replacement](https://docs.unity3d.com/Manual/SL-ShaderReplacement.html) to re-render the entire scene into a Render Texture, this time with just the data that is supposed to go into the gbuffer. Not very elegant, I'm sure you'll agree.

Luckily BRP is not the only option any more. While [Scriptable Render Pipelines](https://docs.unity3d.com/Manual/scriptable-render-pipeline-introduction.html) have not been around for that long and some features that you may want are still missing, it is highly extensible and you can add these missing features yourself.

Including - you guessed it - adding a custom gbuffer. I went through the trouble of figuring out how, so you don't have to.

## What can it do?

Surface Data has an extra `float4` field now called `custom0`:

```cs
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
```

You can write values to it via code:

```cs
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
    
    surfaceData.emission += _Emission.rgb;

    // CUSTOM: Write to the new custom data like you would with any other SurfaceData field.
    surfaceData.custom0 = _Custom0;
}
```
You can write values to it via Shader Graph:

![image](https://github.com/user-attachments/assets/0fce47e3-fc16-4d5a-bc91-77d452397a38)

It ends up in a new gbuffer (contents displayed in the scene view via [URP Debug Draw Modes](https://github.com/RoyTheunissen/URP-Debug-Draw-Modes), which is included in the project):

_**NOTE**: Viewing raw gbuffer contents is an advanced feature and [needs to be enabled in your preferences](https://github.com/RoyTheunissen/URP-Debug-Draw-Modes#:~:text=If%20you%20want%20to%20use%20the%20advanced%20debug%20draw%20modes%2C%20for%20example%20to%20view%20the%20unfiltered%20Gbuffers%2C%20head%20to%20Edit%20%3E%20Preferences...%20%3E%20URP%20Debug%20Draw%20Modes%20%3E%20Active%20Categories%20and%20enable%20the%20Gbuffer%20category)_

![image](https://github.com/user-attachments/assets/17f12942-518f-4cb9-9d78-eaffd523e64e)

This is then decoded from the Gbuffer and put inside `SurfaceData` and `BRDFData`, for you to use as you please. As an example I've made it invert the final colour:

![Custom Gbuffer Example](https://github.com/user-attachments/assets/03e5be36-9522-4def-adc3-2f6edae9ea48)


## What changes did I make?
- I copied the `com.unity.render-pipelines.universal` and `com.unity.shadergraph` packages from the `Library/PackageCache/` folder to the `Packages/` folder [in order to be able to edit them](https://support.unity.com/hc/en-us/articles/9113460764052-How-can-I-modify-built-in-packages).
- I made [various C# and shader code modifications](https://github.com/RoyTheunissen/URP-Custom-Gbuffer/pull/1) to the packages to add the gbuffer and to let Shader Graph shaders write to this new surface data field. Every line of code I touched is marked with a `// CUSTOM: ` comment above or beside it to make it clear what I changed and what I didn't change.
- I made [a few shader code modifications](https://github.com/RoyTheunissen/URP-Custom-Gbuffer/pull/2) to make it possible to write shader code with less duplication, similar to the way [Surface Shaders](https://docs.unity3d.com/Manual/SL-SurfaceShaders.html) used to work in BRP. Every line of code I changed for that feature is marked with a `// CUSTOM: SURFACESHADERS:` comment above or beside it, so it's easy to remove this feature if you don't want it.
  You can also just leave it. If you don't opt-in with `#define SURFACE_SHADER`, your shader compiles like it normally would, or you can use the Shader Graph instead. This surface shader-like setup is based on a [useful example URP shader code repository](https://github.com/phi-lira/UniversalShaderExamples/tree/master/Assets/_ExampleScenes/51_LitPhysicallyBased) by Unity's [Felipe Lira](https://github.com/phi-lira). This feature is a little bit experimental, so use at your own discretion.

## What did I learn from this experiment?
- Firstly, SRP and Shader Graph are super customizable and it's wonderful ✨ Generally speaking, the shader / C# code seems well thought out and deliberately structured, especially considering the absolute metric ton of features and different platforms that it has to support. This is definitely the way forward. Well done, Unity.
- Adding a gbuffer is **not easy**. They clearly did not intend for users to do this, small things could have been done to make this process easier like adding code comments on some of the less intuitive bits of code and defining more constants or macros for the amount / indices of gbuffers (I've added them myself where possible).
- There are methods for initializing `SurfaceData` objects with default values, and there's lots of places where this _is not used_ and a `SurfaceData` object is initialized right then and there with bespoke code, and even _that_ is done in a manner that is inconsistent and therefore not very searchable. This results in very cryptic `output parameter 'X' not completely initialized` errors where the field of the struct in question *is* actually assigned in the method, but it's assigned a value from a _parameter_ that is uninitialized way further up the chain because it comes from an improperly constructed `SurfaceData` object that now has an uninitialized `custom0` field. I won't sugarcoat it: this is not solid engineering. Duplication should be avoided when possible, and in this case it is. If the existing initialization methods were not satisfactory, another one should have been defined. It has cost me hours tracking down all of the compilation errors caused by this.
- The workflow for writing code in SRP is not very good. It involves having to write or copy/paste a lot of duplicated code. This is definitely a step backwards from surface shaders in BRP. I do believe it's possible to improve this workflow with further SRP modifications (the small amount of changes in this project already made a big difference). It's disappointing to see that it's not supported much by Unity themselves. It seems they would prefer everybody to use Shader Graph, and Shader Graph is great, but it's not for everybody.
- The last few points may sound very negative but as a long-time BRP user (this is my first serious look into SRP) I'm actually coming away from it with an optimistic feeling and a willingness to switch to URP for future projects.

## Compatibility

- This project was made in Unity 6 for deferred URP projects. I did go through the trouble of supporting Forward Rendering too, but to support rendering semi-transparent objects.

## Known Issues
- The 'Surface shader' workflow might not support all rendering features. There's a lot of rendering features and not all of them have been tested. It is not mandatory to use this workflow, you can still write your own vertex/fragment functions or use the Shader Graph. Use at your own discretion.
- I've seen the normal maps not being used in the 'Surface Shader' example while the project was set to the Forward rendering path. This problem seemed to go away when I set the project to the Deferred Rendering Path and enabled [Accurate G-buffer Normals](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@13.1/manual/rendering/deferred-rendering-path.html#accurate-g-buffer-normals) and then went back to the Forward Rendering path. This project is for Deferred Rendering path projects anyway so it might not be a problem at all, but I figured I'd mention this in case this issue ever shows up again, for example in semi-transparent objects.

## Contact
[Roy Theunissen](https://roytheunissen.com)

[roy.theunissen@live.nl](mailto:roy.theunissen@live.nl)
