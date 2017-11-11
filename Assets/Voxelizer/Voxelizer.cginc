// Geometry voxelizer effect
// https://github.com/keijiro/GVoxelizer

#include "Common.cginc"
#include "UnityGBuffer.cginc"
#include "UnityStandardUtils.cginc"
#include "SimplexNoise3D.hlsl"

// Cube map shadow caster; Used to render point light shadows on platforms
// that lacks depth cube map support.
#if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
#define PASS_CUBE_SHADOWCASTER
#endif

// Base properties
half4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
half _Glossiness;
half _Metallic;

// Effect properties
half4 _Color2;
half _Glossiness2;
half _Metallic2;

// Edge properties
half3 _EdgeColor;

// Dynamic properties
float4 _EffectVector;

// Vertex input attributes
struct Attributes
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    float2 texcoord : TEXCOORD;
};

// Fragment varyings
struct Varyings
{
    float4 position : SV_POSITION;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass
    float3 shadow : TEXCOORD0;

#elif defined(UNITY_PASS_SHADOWCASTER)
    // Default shadow caster pass

#else
    // GBuffer construction pass
    float3 normal : NORMAL;
    float2 texcoord : TEXCOORD0;
    half3 ambient : TEXCOORD1;
    float4 edge : TEXCOORD2; // barycentric coord (xyz), emission (w)
    float4 wpos_ch : TEXCOORD3; // world position (xyz), channel select (w)

#endif
};

//
// Vertex stage
//

Attributes Vertex(Attributes input)
{
    // Only do object space to world space transform.
    input.position = mul(unity_ObjectToWorld, input.position);
    input.normal = UnityObjectToWorldNormal(input.normal);
    return input;
}

//
// Geometry stage
//

Varyings VertexOutput(float3 wpos, half3 wnrm, float2 uv,
                      float4 edge = 0.5, float channel = 0)
{
    Varyings o;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass: Transfer the shadow vector.
    o.position = UnityWorldToClipPos(float4(wpos, 1));
    o.shadow = wpos - _LightPositionRange.xyz;

#elif defined(UNITY_PASS_SHADOWCASTER)
    // Default shadow caster pass: Apply the shadow bias.
    float scos = dot(wnrm, normalize(UnityWorldSpaceLightDir(wpos)));
    wpos -= wnrm * unity_LightShadowBias.z * sqrt(1 - scos * scos);
    o.position = UnityApplyLinearShadowBias(UnityWorldToClipPos(float4(wpos, 1)));

#else
    // GBuffer construction pass
    o.position = UnityWorldToClipPos(float4(wpos, 1));
    o.normal = wnrm;
    o.texcoord = uv;
    o.ambient = ShadeSHPerVertex(wnrm, 0);
    o.edge = edge;
    o.wpos_ch = float4(wpos, channel);

#endif
    return o;
}

Varyings CubeVertex(
    float3 wpos, half3 wnrm_tri, half3 wnrm_cube, float2 uv,
    float3 bary_tri, float2 bary_cube, float morph, float emission
)
{
    float3 wnrm = normalize(lerp(wnrm_tri, wnrm_cube, morph));
    float3 bary = lerp(bary_tri, float3(bary_cube, 0.5), morph);
    return VertexOutput(wpos, wnrm, uv, float4(bary, emission), 1);
}

Varyings TriangleVertex(float3 wpos, half3 wnrm, float2 uv, float3 bary, float emission)
{
    return VertexOutput(wpos, wnrm, uv, float4(bary, emission), 0);
}

[maxvertexcount(24)]
void Geometry(
    triangle Attributes input[3], uint pid : SV_PrimitiveID,
    inout TriangleStream<Varyings> outStream
)
{
    // Input vertices
    float3 p0 = input[0].position.xyz;
    float3 p1 = input[1].position.xyz;
    float3 p2 = input[2].position.xyz;

    float3 n0 = input[0].normal;
    float3 n1 = input[1].normal;
    float3 n2 = input[2].normal;

    float2 uv0 = input[0].texcoord;
    float2 uv1 = input[1].texcoord;
    float2 uv2 = input[2].texcoord;

    float3 center = (p0 + p1 + p2) / 3;

    // Deformation parameter
    float param = 1 - dot(_EffectVector.xyz, center) + _EffectVector.w;

    // Pass through the vertices if deformation hasn't been started yet.
    if (param < 0)
    {
        outStream.Append(VertexOutput(p0, n0, uv0));
        outStream.Append(VertexOutput(p1, n1, uv1));
        outStream.Append(VertexOutput(p2, n2, uv2));
        outStream.RestartStrip();
        return;
    }

    // Draw nothing at the end of deformation.
    if (param >= 1) return;

    // Choose cube/triangle randomly.
    uint seed = pid * 877;
    if (Random(seed) < 0.05)
    {
        // -- Cube fx --
        // Base triangle -> Expand -> Morph into cube -> Stretch and fade out

        // Triangle animation (simply expand from the centroid)
        float t_anim = 1 + param * 60;
        float3 t_p0 = lerp(center, p0, t_anim);
        float3 t_p1 = lerp(center, p1, t_anim);
        float3 t_p2 = lerp(center, p2, t_anim);

        // Cube animation
        float rnd = Random(seed + 1); // random number, gradient noise
        float4 snoise = snoise_grad(float3(rnd * 2378.34, param * 0.8, 0));

        float move = saturate(param * 4 - 3); // stretch/move param
        move = move * move;

        float3 pos = center + snoise.xyz * 0.02; // cube position
        pos.y += move * rnd;

        float3 scale = float2(1 - move, 1 + move * 5).xyx; // cube scale anim
        scale *= 0.05 * saturate(1 + snoise.w * 2);

        float edge = saturate(param * 5); // Edge color (emission power)

        // Cube points calculation
        float morph = smoothstep(0.25, 0.5, param);
        float3 c_p0 = lerp(t_p2, pos + float3(-1, -1, -1) * scale, morph);
        float3 c_p1 = lerp(t_p2, pos + float3(+1, -1, -1) * scale, morph);
        float3 c_p2 = lerp(t_p0, pos + float3(-1, +1, -1) * scale, morph);
        float3 c_p3 = lerp(t_p1, pos + float3(+1, +1, -1) * scale, morph);
        float3 c_p4 = lerp(t_p2, pos + float3(-1, -1, +1) * scale, morph);
        float3 c_p5 = lerp(t_p2, pos + float3(+1, -1, +1) * scale, morph);
        float3 c_p6 = lerp(t_p0, pos + float3(-1, +1, +1) * scale, morph);
        float3 c_p7 = lerp(t_p1, pos + float3(+1, +1, +1) * scale, morph);

        // Vertex outputs
        float3 c_n = float3(-1, 0, 0);
        outStream.Append(CubeVertex(c_p2, n0, c_n, uv0, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(c_p0, n2, c_n, uv2, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(c_p6, n0, c_n, uv0, float3(0, 0, 1), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(c_p4, n2, c_n, uv2, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(1, 0, 0);
        outStream.Append(CubeVertex(c_p1, n2, c_n, uv2, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(c_p3, n1, c_n, uv1, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(c_p5, n2, c_n, uv2, float3(0, 0, 1), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(c_p7, n1, c_n, uv1, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, -1, 0);
        outStream.Append(CubeVertex(c_p0, n2, c_n, uv2, float3(1, 0, 0), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(c_p1, n2, c_n, uv2, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(c_p4, n2, c_n, uv2, float3(1, 0, 0), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(c_p5, n2, c_n, uv2, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, 1, 0);
        outStream.Append(CubeVertex(c_p3, n1, c_n, uv1, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(c_p2, n0, c_n, uv0, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(c_p7, n1, c_n, uv1, float3(0, 0, 1), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(c_p6, n0, c_n, uv0, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, 0, -1);
        outStream.Append(CubeVertex(c_p1, n2, c_n, uv2, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(c_p0, n2, c_n, uv2, float3(0, 0, 1), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(c_p3, n1, c_n, uv1, float3(0, 1, 0), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(c_p2, n0, c_n, uv0, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, 0, 1);
        outStream.Append(CubeVertex(c_p4, -n2, c_n, uv2, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(c_p5, -n2, c_n, uv2, float3(0, 0, 1), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(c_p6, -n0, c_n, uv0, float3(0, 1, 0), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(c_p7, -n1, c_n, uv1, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();
    }
    else
    {
        // -- Triangle fx --
        // Simple scattering animation

        // We use smoothstep to make naturally damped linear motion.
        // Q. Why don't you use 1-pow(1-param,2)?
        // A. Smoothstep is cooler than it. Forget Newtonian physics.
        float ss_param = smoothstep(0, 1, param);

        // Random motion
        float3 move = RandomVector(seed + 1) * ss_param * 0.5;

        // Random rotation
        float3 rot_angles = (RandomVector01(seed + 1) - 0.5) * 100;
        float3x3 rot_m = Euler3x3(rot_angles * ss_param);

        // Simple shrink
        float scale = 1 - ss_param;

        // Apply the animation.
        float3 t_p0 = mul(rot_m, p0 - center) * scale + center + move;
        float3 t_p1 = mul(rot_m, p1 - center) * scale + center + move;
        float3 t_p2 = mul(rot_m, p2 - center) * scale + center + move;
        float3 normal = normalize(cross(t_p1 - t_p0, t_p2 - t_p0));

        // Edge color (emission power) animation
        float edge = smoothstep(0, 0.1, param); // ease-in
        edge *= 1 + 20 * smoothstep(0, 0.1, 0.1 - param); // peak -> release

        // Vertex outputs (front face)
        outStream.Append(TriangleVertex(t_p0, normal, uv0, float3(1, 0, 0), edge));
        outStream.Append(TriangleVertex(t_p1, normal, uv1, float3(0, 1, 0), edge));
        outStream.Append(TriangleVertex(t_p2, normal, uv2, float3(0, 0, 1), edge));
        outStream.RestartStrip();

        // Vertex outputs (back face)
        outStream.Append(TriangleVertex(t_p0, -normal, uv0, float3(1, 0, 0), edge));
        outStream.Append(TriangleVertex(t_p2, -normal, uv2, float3(0, 0, 1), edge));
        outStream.Append(TriangleVertex(t_p1, -normal, uv1, float3(0, 1, 0), edge));
        outStream.RestartStrip();
    }
}

//
// Fragment phase
//

#if defined(PASS_CUBE_SHADOWCASTER)

// Cube map shadow caster pass
half4 Fragment(Varyings input) : SV_Target
{
    float depth = length(input.shadow) + unity_LightShadowBias.x;
    return UnityEncodeCubeShadowDepth(depth * _LightPositionRange.w);
}

#elif defined(UNITY_PASS_SHADOWCASTER)

// Default shadow caster pass
half4 Fragment() : SV_Target { return 0; }

#else

// GBuffer construction pass
void Fragment(
    Varyings input,
    out half4 outGBuffer0 : SV_Target0,
    out half4 outGBuffer1 : SV_Target1,
    out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3
)
{
    half3 albedo = tex2D(_MainTex, input.texcoord).rgb * _Color.rgb;

    // PBS workflow conversion (metallic -> specular)
    half3 c1_diff, c1_spec, c2_diff, c2_spec;
    half not_in_use;

    c1_diff = DiffuseAndSpecularFromMetallic(
        albedo, _Metallic,       // input
        c1_spec, not_in_use      // output
    );

    c2_diff = DiffuseAndSpecularFromMetallic(
        _Color2.rgb, _Metallic2, // input
        c2_spec, not_in_use      // output
    );

    // Detect fixed-width edges with using screen space derivatives of
    // barycentric coordinates.
    float3 bcc = input.edge.xyz;
    float3 fw = fwidth(bcc);
    float3 edge3 = min(smoothstep(fw / 2, fw,     bcc),
                       smoothstep(fw / 2, fw, 1 - bcc));
    float edge = 1 - min(min(edge3.x, edge3.y), edge3.z);

    // Update the GBuffer.
    UnityStandardData data;
    float ch = input.wpos_ch.w;
    data.diffuseColor = lerp(c1_diff, c2_diff, ch);
    data.occlusion = 1;
    data.specularColor = lerp(c1_spec, c2_spec, ch);
    data.smoothness = lerp(_Glossiness, _Glossiness2, ch);
    data.normalWorld = input.normal;
    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    // Output ambient light and edge emission to the emission buffer.
    half3 sh = ShadeSHPerPixel(data.normalWorld, input.ambient, input.wpos_ch.xyz);
    outEmission = half4(sh * data.diffuseColor + _EdgeColor * input.edge.w * edge, 1);
}

#endif
