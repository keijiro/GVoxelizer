#include "Common.cginc"
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

// Vertex stage
Attributes Vertex(Attributes input)
{
    input.position = mul(unity_ObjectToWorld, input.position);
    input.normal = UnityObjectToWorldNormal(input.normal);
    return input;
}

// Geometry stage
Varyings SetGeoOut(float4 position, half3 normal, half3 color, half param)
{
    Varyings o;
    o.position = position;
    o.color = lerp((normal + 1) / 2, color, param);
    return o;
}

[maxvertexcount(36)]
void Geometry(
    triangle Attributes input[3],
    uint pid : SV_PrimitiveID,
    inout TriangleStream<Varyings> outStream
)
{
    float time = _Time.y;

    // Random number per triangle
    float prnd = Random(pid);

    // Noise per triangle
    float4 pnoise = snoise_grad(float3(prnd * 2378.34, time * 0.8, 0));

    // Is this triangle going to be shrinked?
    bool shrink = prnd < 0.95;

    // Input vertices
    float3 vp0 = input[0].position.xyz; float3 n0 = input[0].normal;
    float3 vp1 = input[1].position.xyz; float3 n1 = input[1].normal;
    float3 vp2 = input[2].position.xyz; float3 n2 = input[2].normal;

    // Centroid of the triangle
    float3 center = (vp0 + vp1 + vp2) / 3;

    // Deformation parameter
    float param = saturate(0.5 + sin(center.y * 0.4 + time * 0.6));

    // Triangle vertices
    float tparam = shrink ? saturate(1 - param * 20) : (1 + param * 60);
    float3 tp0 = lerp(center, vp0, tparam);
    float3 tp1 = lerp(center, vp1, tparam);
    float3 tp2 = lerp(center, vp2, tparam);

    // Cube size
    float size = (shrink ? 0 : 0.05) * saturate(1 + pnoise.w * 2);

    // Cube center
    float3 cube = center + pnoise.xyz * 0.02;

    // Cube vertices
    float cparam = saturate(param * 4 - 3);
    float3 csize = float3(1 - cparam, 1 + cparam * 4, 1 - cparam) * size;
    float3 cp0 = cube + float3(-1, -1, -1) * csize;
    float3 cp1 = cube + float3(+1, -1, -1) * csize;
    float3 cp2 = cube + float3(-1, +1, -1) * csize;
    float3 cp3 = cube + float3(+1, +1, -1) * csize;
    float3 cp4 = cube + float3(-1, -1, +1) * csize;
    float3 cp5 = cube + float3(+1, -1, +1) * csize;
    float3 cp6 = cube + float3(-1, +1, +1) * csize;
    float3 cp7 = cube + float3(+1, +1, +1) * csize;

    // Lerping vertices
    float oparam = saturate(param * 2 - 0.5);
    float4 op0 = UnityWorldToClipPos(float4(lerp(tp0, cp0, oparam), 1));
    float4 op1 = UnityWorldToClipPos(float4(lerp(tp0, cp1, oparam), 1));
    float4 op2 = UnityWorldToClipPos(float4(lerp(tp0, cp2, oparam), 1));
    float4 op3 = UnityWorldToClipPos(float4(lerp(tp1, cp3, oparam), 1));
    float4 op4 = UnityWorldToClipPos(float4(lerp(tp1, cp4, oparam), 1));
    float4 op5 = UnityWorldToClipPos(float4(lerp(tp1, cp5, oparam), 1));
    float4 op6 = UnityWorldToClipPos(float4(lerp(tp2, cp6, oparam), 1));
    float4 op7 = UnityWorldToClipPos(float4(lerp(tp2, cp7, oparam), 1));

    half3 color = Hue2RGB(Random(pid * 6));
    outStream.Append(SetGeoOut(op2, n0, color, oparam));
    outStream.Append(SetGeoOut(op0, n0, color, oparam));
    outStream.Append(SetGeoOut(op6, n2, color, oparam));
    outStream.Append(SetGeoOut(op4, n1, color, oparam));
    outStream.RestartStrip();

    color = Hue2RGB(Random(pid * 6 + 1));
    outStream.Append(SetGeoOut(op1, n0, color, oparam));
    outStream.Append(SetGeoOut(op3, n1, color, oparam));
    outStream.Append(SetGeoOut(op5, n1, color, oparam));
    outStream.Append(SetGeoOut(op7, n2, color, oparam));
    outStream.RestartStrip();

    color = Hue2RGB(Random(pid * 6 + 2));
    outStream.Append(SetGeoOut(op0, n0, color, oparam));
    outStream.Append(SetGeoOut(op1, n0, color, oparam));
    outStream.Append(SetGeoOut(op4, n1, color, oparam));
    outStream.Append(SetGeoOut(op5, n1, color, oparam));
    outStream.RestartStrip();

    color = Hue2RGB(Random(pid * 6 + 3));
    outStream.Append(SetGeoOut(op3, n1, color, oparam));
    outStream.Append(SetGeoOut(op2, n0, color, oparam));
    outStream.Append(SetGeoOut(op7, n2, color, oparam));
    outStream.Append(SetGeoOut(op6, n2, color, oparam));
    outStream.RestartStrip();

    color = Hue2RGB(Random(pid * 6 + 4));
    outStream.Append(SetGeoOut(op1, n0, color, oparam));
    outStream.Append(SetGeoOut(op0, n0, color, oparam));
    outStream.Append(SetGeoOut(op3, n1, color, oparam));
    outStream.Append(SetGeoOut(op2, n1, color, oparam));
    outStream.RestartStrip();

    color = Hue2RGB(Random(pid * 6 + 5));
    outStream.Append(SetGeoOut(op4, n1, color, oparam));
    outStream.Append(SetGeoOut(op5, n1, color, oparam));
    outStream.Append(SetGeoOut(op6, n2, color, oparam));
    outStream.Append(SetGeoOut(op7, n2, color, oparam));
    outStream.RestartStrip();
}

// Fragment phase
half4 Fragment(Varyings input) : SV_Target
{
    return half4(input.color, 1);
}
