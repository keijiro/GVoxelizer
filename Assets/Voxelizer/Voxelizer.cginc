// Geometry voxelizer effect
// https://github.com/keijiro/GVoxelizer

#include "Common.cginc"
#include "UnityGBuffer.cginc"
#include "SimplexNoise3D.hlsl"

// Base properties
half4 _Color;
half3 _SpecColor;
half _Glossiness;

// Effect properties
half4 _Color2;
half3 _SpecColor2;
half _Glossiness2;

// Edge properties
half3 _EdgeColor;

// Dynamic properties
float4 _EffectVector;

// Vertex input attributes
struct Attributes
{
    float4 position : POSITION;
    float3 normal : NORMAL;
};

// Fragment varyings
struct Varyings
{
    float4 position : SV_POSITION;
    float3 normal: NORMAL;

    // Edge parameters: barycentric (xyz), emission (w)
    float4 edge : TEXCOORD0;

    // Material options: channel select (x)
    float option : TEXCOORD1;
};

// Vertex stage
Attributes Vertex(Attributes input)
{
    input.position = mul(unity_ObjectToWorld, input.position);
    input.normal = UnityObjectToWorldNormal(input.normal);
    return input;
}

// Geometry stage
float4 CubePointClipPos(float3 v_tri, float3 origin, float3 v_cube, float3 scale, float morph)
{
    float3 p = lerp(v_tri, origin + v_cube * scale, morph);
    return UnityWorldToClipPos(float4(p, 1));
}

Varyings GeoOutWPosNrm(float3 wp, half3 wn)
{
    Varyings o;
    o.position = UnityWorldToClipPos(float4(wp, 1));
    o.normal = wn;
    o.edge = 0.5;
    o.option = 0;
    return o;
}

Varyings GeoOutCube(
    float4 cp,
    half3 n_tri, half3 n_cube,
    float3 bary_tri, float2 bary_cube,
    float morph, float emission
)
{
    Varyings o;
    o.position = cp;
    o.normal = normalize(lerp(n_tri, n_cube, morph));
    o.edge = float4(lerp(bary_tri, float3(bary_cube, 0.5), morph), emission);
    o.option = 1;
    return o;
}

Varyings GeoOutTri(float3 wp, half3 wn, float3 bary, float emission)
{
    Varyings o;
    o.position = UnityWorldToClipPos(float4(wp, 1));
    o.normal = wn;
    o.edge = float4(bary, emission);
    o.option = 0;
    return o;
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

    float3 center = (p0 + p1 + p2) / 3;

    // Deformation parameter
    float param = 1 - dot(_EffectVector.xyz, center) + _EffectVector.w;

    // Pass through the vertices if deformation hasn't been started yet.
    if (param < 0)
    {
        outStream.Append(GeoOutWPosNrm(p0, n0));
        outStream.Append(GeoOutWPosNrm(p1, n1));
        outStream.Append(GeoOutWPosNrm(p2, n2));
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
        float4 c_cp0 = CubePointClipPos(t_p2, pos, float3(-1, -1, -1), scale, morph);
        float4 c_cp1 = CubePointClipPos(t_p2, pos, float3(+1, -1, -1), scale, morph);
        float4 c_cp2 = CubePointClipPos(t_p0, pos, float3(-1, +1, -1), scale, morph);
        float4 c_cp3 = CubePointClipPos(t_p1, pos, float3(+1, +1, -1), scale, morph);
        float4 c_cp4 = CubePointClipPos(t_p2, pos, float3(-1, -1, +1), scale, morph);
        float4 c_cp5 = CubePointClipPos(t_p2, pos, float3(+1, -1, +1), scale, morph);
        float4 c_cp6 = CubePointClipPos(t_p0, pos, float3(-1, +1, +1), scale, morph);
        float4 c_cp7 = CubePointClipPos(t_p1, pos, float3(+1, +1, +1), scale, morph);

        // Vertex outputs
        float3 c_n = float3(-1, 0, 0);
        outStream.Append(GeoOutCube(c_cp2, n0, c_n, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp0, n2, c_n, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp6, n0, c_n, float3(0, 0, 1), float2(0, 1), morph, edge));
        outStream.Append(GeoOutCube(c_cp4, n2, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(1, 0, 0);
        outStream.Append(GeoOutCube(c_cp1, n2, c_n, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp3, n1, c_n, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp5, n2, c_n, float3(0, 0, 1), float2(0, 1), morph, edge));
        outStream.Append(GeoOutCube(c_cp7, n1, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, -1, 0);
        outStream.Append(GeoOutCube(c_cp0, n2, c_n, float3(1, 0, 0), float2(0, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp1, n2, c_n, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp4, n2, c_n, float3(1, 0, 0), float2(0, 1), morph, edge));
        outStream.Append(GeoOutCube(c_cp5, n2, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, 1, 0);
        outStream.Append(GeoOutCube(c_cp3, n1, c_n, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp2, n0, c_n, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp7, n1, c_n, float3(0, 0, 1), float2(0, 1), morph, edge));
        outStream.Append(GeoOutCube(c_cp6, n0, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, 0, -1);
        outStream.Append(GeoOutCube(c_cp1, n2, c_n, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp0, n2, c_n, float3(0, 0, 1), float2(1, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp3, n1, c_n, float3(0, 1, 0), float2(0, 1), morph, edge));
        outStream.Append(GeoOutCube(c_cp2, n0, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, 0, 1);
        outStream.Append(GeoOutCube(c_cp4, -n2, c_n, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp5, -n2, c_n, float3(0, 0, 1), float2(1, 0), morph, edge));
        outStream.Append(GeoOutCube(c_cp6, -n0, c_n, float3(0, 1, 0), float2(0, 1), morph, edge));
        outStream.Append(GeoOutCube(c_cp7, -n1, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
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
        outStream.Append(GeoOutTri(t_p0, normal, float3(1, 0, 0), edge));
        outStream.Append(GeoOutTri(t_p1, normal, float3(0, 1, 0), edge));
        outStream.Append(GeoOutTri(t_p2, normal, float3(0, 0, 1), edge));
        outStream.RestartStrip();

        // Vertex outputs (back face)
        outStream.Append(GeoOutTri(t_p0, -normal, float3(1, 0, 0), edge));
        outStream.Append(GeoOutTri(t_p2, -normal, float3(0, 0, 1), edge));
        outStream.Append(GeoOutTri(t_p1, -normal, float3(0, 1, 0), edge));
        outStream.RestartStrip();
    }
}

// Fragment phase
#ifdef VOXELIZER_SHADOW_CASTER

half4 Fragment() : SV_Target { return 0; }

#else

void Fragment(
    Varyings input,
    out half4 outGBuffer0 : SV_Target0,
    out half4 outGBuffer1 : SV_Target1,
    out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3
)
{
    // Detect fixed-width edges with using screen space derivatives of
    // barycentric coordinates.
    float3 bcc = input.edge.xyz;
    float3 fw = abs(fwidth(bcc));
    float3 edge3 = min(smoothstep(fw / 2, fw,     bcc),
                       smoothstep(fw / 2, fw, 1 - bcc));
    float edge = 1 - min(min(edge3.x, edge3.y), edge3.z);

    // Output to GBuffers.
    UnityStandardData data;
    float ch = input.option;
    data.diffuseColor = lerp(_Color.rgb, _Color2.rgb, ch);
    data.occlusion = 1;
    data.specularColor = lerp(_SpecColor, _SpecColor2, ch);
    data.smoothness = lerp(_Glossiness, _Glossiness2, ch);
    data.normalWorld = input.normal;
    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    // Edge emission
    outEmission = half4(_EdgeColor * input.edge.w * edge, 0);
}

#endif
