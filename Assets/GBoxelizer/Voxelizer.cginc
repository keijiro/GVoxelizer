// Geometry voxelizer effect
// https://github.com/keijiro/GVoxelizer

#include "Common.cginc"
#include "SimplexNoise3D.hlsl"

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
    float4 texcoord : TEXCOORD;
};

// Vertex stage
Attributes Vertex(Attributes input)
{
    input.position = mul(unity_ObjectToWorld, input.position);
    input.normal = UnityObjectToWorldNormal(input.normal);
    return input;
}

// Geometry stage
float4 CubePoint(float3 v_tri, float3 pos, float3 v_cube, float3 size, float param)
{
    float3 p = lerp(v_tri, pos + v_cube * size, param);
    return UnityWorldToClipPos(float4(p, 1));
}

Varyings SetGeoOut(float4 pos, float3 bary, float cube)
{
    Varyings o;
    o.position = pos;
    o.texcoord = float4(bary, cube);
    return o;
}

Varyings SetGeoOut2(float4 pos, float3 bary1, float2 bary2, float cube)
{
    Varyings o;
    o.position = pos;
    o.texcoord = float4(lerp(bary1, float3(bary2, 0.5), cube), cube);
    return o;
}

[maxvertexcount(24)]
void Geometry(
    triangle Attributes input[3], uint pid : SV_PrimitiveID,
    inout TriangleStream<Varyings> outStream
)
{
    // Random number seed
    uint seed = pid * 877;

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

    // Draw nothing at the end of deformation.
    if (param < 0 || param >= 1) return;

    // Choose cube/triangle randomly.
    if (Random(seed) < 0.05)
    {
        // Random number per cube
        float rnd = Random(seed + 1);

        // Simplex noise & gradients
        float4 snoise = snoise_grad(float3(rnd * 2378.34, param * 0.8, 0));

        // Triangle animation
        float t_anim = 1 + param * 60;
        float3 t_p0 = lerp(center, p0, t_anim);
        float3 t_p1 = lerp(center, p1, t_anim);
        float3 t_p2 = lerp(center, p2, t_anim);

        // Cube animation
        float c_anim = saturate(param * 4 - 3);
        c_anim = c_anim * c_anim;

        float3 c_size = float2(1 - c_anim, 1 + c_anim * 5).xyx;
        c_size *= 0.05 * saturate(1 + snoise.w * 2);

        float3 c_p = center + snoise.xyz * 0.02;
        c_p.y += c_anim * Random(seed + 2);

        // Vertices (with triangle -> cube defromation)
        float c_param = smoothstep(0.25, 0.5, param);
        float4 c_p0 = CubePoint(t_p0, c_p, float3(-1, -1, -1), c_size, c_param);
        float4 c_p1 = CubePoint(t_p0, c_p, float3(+1, -1, -1), c_size, c_param);
        float4 c_p2 = CubePoint(t_p0, c_p, float3(-1, +1, -1), c_size, c_param);
        float4 c_p3 = CubePoint(t_p1, c_p, float3(+1, +1, -1), c_size, c_param);
        float4 c_p4 = CubePoint(t_p1, c_p, float3(-1, -1, +1), c_size, c_param);
        float4 c_p5 = CubePoint(t_p1, c_p, float3(+1, -1, +1), c_size, c_param);
        float4 c_p6 = CubePoint(t_p2, c_p, float3(-1, +1, +1), c_size, c_param);
        float4 c_p7 = CubePoint(t_p2, c_p, float3(+1, +1, +1), c_size, c_param);

        // Output the vertices
        outStream.Append(SetGeoOut2(c_p2, float3(0, 0, 1), float2(0, 0), c_param));
        outStream.Append(SetGeoOut2(c_p0, float3(1, 0, 0), float2(1, 0), c_param));
        outStream.Append(SetGeoOut2(c_p6, float3(0, 1, 0), float2(0, 1), c_param));
        outStream.Append(SetGeoOut2(c_p4, float3(1, 0, 0), float2(1, 1), c_param));
        outStream.RestartStrip();

        outStream.Append(SetGeoOut2(c_p1, float3(0, 0, 1), float2(0, 0), c_param));
        outStream.Append(SetGeoOut2(c_p3, float3(1, 0, 0), float2(1, 0), c_param));
        outStream.Append(SetGeoOut2(c_p5, float3(0, 1, 0), float2(0, 1), c_param));
        outStream.Append(SetGeoOut2(c_p7, float3(1, 0, 0), float2(1, 1), c_param));
        outStream.RestartStrip();

        outStream.Append(SetGeoOut2(c_p0, float3(0, 0, 1), float2(0, 0), c_param));
        outStream.Append(SetGeoOut2(c_p1, float3(1, 0, 0), float2(1, 0), c_param));
        outStream.Append(SetGeoOut2(c_p4, float3(0, 1, 0), float2(0, 1), c_param));
        outStream.Append(SetGeoOut2(c_p5, float3(1, 0, 0), float2(1, 1), c_param));
        outStream.RestartStrip();

        outStream.Append(SetGeoOut2(c_p3, float3(0, 0, 1), float2(0, 0), c_param));
        outStream.Append(SetGeoOut2(c_p2, float3(1, 0, 0), float2(1, 0), c_param));
        outStream.Append(SetGeoOut2(c_p7, float3(0, 1, 0), float2(0, 1), c_param));
        outStream.Append(SetGeoOut2(c_p6, float3(1, 0, 0), float2(1, 1), c_param));
        outStream.RestartStrip();

        outStream.Append(SetGeoOut2(c_p1, float3(0, 0, 1), float2(0, 0), c_param));
        outStream.Append(SetGeoOut2(c_p0, float3(1, 0, 0), float2(1, 0), c_param));
        outStream.Append(SetGeoOut2(c_p3, float3(0, 1, 0), float2(0, 1), c_param));
        outStream.Append(SetGeoOut2(c_p2, float3(1, 0, 0), float2(1, 1), c_param));
        outStream.RestartStrip();

        outStream.Append(SetGeoOut2(c_p4, float3(0, 0, 1), float2(0, 0), c_param));
        outStream.Append(SetGeoOut2(c_p5, float3(1, 0, 0), float2(1, 0), c_param));
        outStream.Append(SetGeoOut2(c_p6, float3(0, 1, 0), float2(0, 1), c_param));
        outStream.Append(SetGeoOut2(c_p7, float3(1, 0, 0), float2(1, 1), c_param));
        outStream.RestartStrip();
    }
    else
    {
        float ss_param = smoothstep(0, 1, param);

        // Rotation
        float3 rot_angles = (RandomVector01(seed + 1) - 0.5) * 100;
        float3x3 rot_m = Euler3x3(rot_angles * ss_param);

        // Transform
        float3 move = RandomVector(seed + 1) * ss_param * 0.5;
        float scale = 1 - ss_param;
        float3 t_p0 = mul(rot_m, p0 - center) * scale + center + move;
        float3 t_p1 = mul(rot_m, p1 - center) * scale + center + move;
        float3 t_p2 = mul(rot_m, p2 - center) * scale + center + move;

        // Vertex outputs
        float rnd = Random(seed + 10);
        outStream.Append(SetGeoOut(UnityWorldToClipPos(float4(t_p0, 1)), float3(1, 0, 0), 0));
        outStream.Append(SetGeoOut(UnityWorldToClipPos(float4(t_p1, 1)), float3(0, 1, 0), 0));
        outStream.Append(SetGeoOut(UnityWorldToClipPos(float4(t_p2, 1)), float3(0, 0, 1), 0));
        outStream.RestartStrip();
    }
}

// Fragment phase
half4 Fragment(Varyings input) : SV_Target
{
    float3 bcc = input.texcoord.xyz;
    float3 fw = abs(fwidth(bcc));
    float3 wire3 = min(smoothstep(fw / 2, fw, bcc), smoothstep(fw / 2, fw, 1 - bcc));
    float wire = 1 - min(min(wire3.x, wire3.y), wire3.z);
    return lerp(0.01, half4(2, 0, 0, 0), wire);
}
