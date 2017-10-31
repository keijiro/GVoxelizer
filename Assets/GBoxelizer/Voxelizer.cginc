#include "UnityCG.cginc"
#include "SimplexNoise3D.hlsl"

float _Voxelize;

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
    fixed3 color : COLOR;
};

// Vertex phase
Attributes Vertex(Attributes input)
{
    input.position = mul(unity_ObjectToWorld, input.position);
    input.normal = UnityObjectToWorldNormal(input.normal);
    return input;
}

// Hash function from H. Schechter & R. Bridson, goo.gl/RXiKaH
uint Hash(uint s)
{
    s ^= 2747636419u;
    s *= 2654435769u;
    s ^= s >> 16;
    s *= 2654435769u;
    s ^= s >> 16;
    s *= 2654435769u;
    return s;
}

float Random(uint seed)
{
    return float(Hash(seed)) / 4294967295.0; // 2^32-1
}

half3 Hue2RGB(half h)
{
    h = frac(saturate(h)) * 6 - 2;
    half3 rgb = saturate(half3(abs(h - 1) - 1, 2 - abs(h), 2 - abs(h - 2)));
#ifndef UNITY_COLORSPACE_GAMMA
    rgb = GammaToLinearSpace(rgb);
#endif
    return rgb;
}

float3x3 Euler3x3(float3 v)
{
    float sx, cx;
    float sy, cy;
    float sz, cz;

    sincos(v.x, sx, cx);
    sincos(v.y, sy, cy);
    sincos(v.z, sz, cz);

    float3 row1 = float3(sx*sy*sz + cy*cz, sx*sy*cz - cy*sz, cx*sy);
    float3 row3 = float3(sx*cy*sz - sy*cz, sx*cy*cz + sy*sz, cx*cy);
    float3 row2 = float3(cx*sz, cx*cz, -sx);

    return float3x3(row1, row2, row3);
}

Varyings SetGeoOut(float4 position, half3 normal, half3 color, half param)
{
    Varyings o;
    o.position = position;
    o.color = lerp((normal + 1) / 2, color, param);
    return o;
}

// Geometry phase
[maxvertexcount(36)]
void Geometry(
    triangle Attributes input[3],
    uint pid : SV_PrimitiveID,
    inout TriangleStream<Varyings> outStream
)
{
    float3 p0 = input[0].position.xyz;
    float3 p1 = input[1].position.xyz;
    float3 p2 = input[2].position.xyz;

    float3 n0 = input[0].normal;
    float3 n1 = input[1].normal;
    float3 n2 = input[2].normal;

    float3 center = (p0 + p1 + p2) / 3;
    //center = round(center * 20) / 20;

    float w = 0.05;//length(p0 - center) / 2;
    //float param = saturate(0.5 + sin(center.y * 0.8 + _Time.y * 1));
    float param = saturate(0.5 + snoise(center * 2.1 + _Time.y) * 0.3 + sin(center.y * 0.8 + _Time.y * 1));

    //float4 sn = snoise_grad(center * 8 + _Time.y * 0.8);
    float4 sn = snoise_grad(float3(Random(pid) * 2378.34, _Time.y * 0.8, 1));
    float3x3 rot = Euler3x3(float3(0,  param * UNITY_PI * 2, 0));
    w *= saturate(1 + sn.w * 2);

    bool shrink = Random(pid) < 0.95;
    if (shrink) w = 0;

    float3 center2 = center + sn.xyz * 0.02;

    float4 wp0 = float4(center2 + mul(rot, float3(-1, -1, -1)) * w, 1);
    float4 wp1 = float4(center2 + mul(rot, float3(+1, -1, -1)) * w, 1);
    float4 wp2 = float4(center2 + mul(rot, float3(-1, +1, -1)) * w, 1);
    float4 wp3 = float4(center2 + mul(rot, float3(+1, +1, -1)) * w, 1);
    float4 wp4 = float4(center2 + mul(rot, float3(-1, -1, +1)) * w, 1);
    float4 wp5 = float4(center2 + mul(rot, float3(+1, -1, +1)) * w, 1);
    float4 wp6 = float4(center2 + mul(rot, float3(-1, +1, +1)) * w, 1);
    float4 wp7 = float4(center2 + mul(rot, float3(+1, +1, +1)) * w, 1);

    {
        float s = shrink ? 0 : 10;
        p0 = lerp(p0, center + (p0 - center) * s, saturate(param * 10));
        p1 = lerp(p1, center + (p1 - center) * s, saturate(param * 10));
        p2 = lerp(p2, center + (p2 - center) * s, saturate(param * 10));
    }

    wp0.xyz = lerp(p0, wp0.xyz, param);
    wp1.xyz = lerp(p0, wp1.xyz, param);
    wp2.xyz = lerp(p0, wp2.xyz, param);

    wp3.xyz = lerp(p1, wp3.xyz, param);
    wp4.xyz = lerp(p1, wp4.xyz, param);
    wp5.xyz = lerp(p1, wp5.xyz, param);

    wp6.xyz = lerp(p2, wp6.xyz, param);
    wp7.xyz = lerp(p2, wp7.xyz, param);

    wp0 = UnityWorldToClipPos(wp0);
    wp1 = UnityWorldToClipPos(wp1);
    wp2 = UnityWorldToClipPos(wp2);
    wp3 = UnityWorldToClipPos(wp3);
    wp4 = UnityWorldToClipPos(wp4);
    wp5 = UnityWorldToClipPos(wp5);
    wp6 = UnityWorldToClipPos(wp6);
    wp7 = UnityWorldToClipPos(wp7);

    half3 color = Hue2RGB(Random(pid * 6));
    outStream.Append(SetGeoOut(wp2, n0, color, param));
    outStream.Append(SetGeoOut(wp0, n0, color, param));
    outStream.Append(SetGeoOut(wp6, n2, color, param));
    outStream.Append(SetGeoOut(wp4, n1, color, param));
    outStream.RestartStrip();

    color = Hue2RGB(Random(pid * 6 + 1));
    outStream.Append(SetGeoOut(wp1, n0, color, param));
    outStream.Append(SetGeoOut(wp3, n1, color, param));
    outStream.Append(SetGeoOut(wp5, n1, color, param));
    outStream.Append(SetGeoOut(wp7, n2, color, param));
    outStream.RestartStrip();

    color = Hue2RGB(Random(pid * 6 + 2));
    outStream.Append(SetGeoOut(wp0, n0, color, param));
    outStream.Append(SetGeoOut(wp1, n0, color, param));
    outStream.Append(SetGeoOut(wp4, n1, color, param));
    outStream.Append(SetGeoOut(wp5, n1, color, param));
    outStream.RestartStrip();

    color = Hue2RGB(Random(pid * 6 + 3));
    outStream.Append(SetGeoOut(wp3, n1, color, param));
    outStream.Append(SetGeoOut(wp2, n0, color, param));
    outStream.Append(SetGeoOut(wp7, n2, color, param));
    outStream.Append(SetGeoOut(wp6, n2, color, param));
    outStream.RestartStrip();

    color = Hue2RGB(Random(pid * 6 + 4));
    outStream.Append(SetGeoOut(wp1, n0, color, param));
    outStream.Append(SetGeoOut(wp0, n0, color, param));
    outStream.Append(SetGeoOut(wp3, n1, color, param));
    outStream.Append(SetGeoOut(wp2, n1, color, param));
    outStream.RestartStrip();

    color = Hue2RGB(Random(pid * 6 + 5));
    outStream.Append(SetGeoOut(wp4, n1, color, param));
    outStream.Append(SetGeoOut(wp5, n1, color, param));
    outStream.Append(SetGeoOut(wp6, n2, color, param));
    outStream.Append(SetGeoOut(wp7, n2, color, param));
    outStream.RestartStrip();
}

// Fragment phase
half4 Fragment(Varyings input) : SV_Target
{
    return half4(input.color, 1);
}
