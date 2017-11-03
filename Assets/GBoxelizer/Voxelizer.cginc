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
float4 CubePoint(float3 v_tri, float3 pos, float3 v_cube, float3 size, float param)
{
    float3 p = lerp(v_tri, pos + v_cube * size, param);
    return UnityWorldToClipPos(float4(p, 1));
}

Varyings SetGeoOut(float4 position, half3 normal, half3 color, half param)
{
    Varyings o;
    o.position = position;
    o.color = lerp((normal + 1) / 2, color, param);
    return o;
}

Varyings SetTriangleGeoOut(float3 center, float3 vert, float param, float3 normal)
{
    Varyings o;
    o.position = UnityWorldToClipPos(float4(lerp(center, vert, param), 1));
    o.color = (normal + 1) / 2;
    return o;
}

[maxvertexcount(24)]
void Geometry(
    triangle Attributes input[3],
    uint pid : SV_PrimitiveID,
    inout TriangleStream<Varyings> outStream
)
{
    float time = _Time.y;

    // Random number
    float rnd = Random(pid);

    // Input vertices
    float3 p0 = input[0].position.xyz;
    float3 p1 = input[1].position.xyz;
    float3 p2 = input[2].position.xyz;

    float3 n0 = input[0].normal;
    float3 n1 = input[1].normal;
    float3 n2 = input[2].normal;

    float3 center = (p0 + p1 + p2) / 3;

    // Deformation parameter
    float param = saturate(0.5 + sin(center.y * 0.4 + time * 0.6));

    // Cube or triangle?
    if (rnd < 0.05)
    {
        // Recalculate the random number.
        rnd = Random(pid + 100000);

        // Simplex noise & gradients
        float4 snoise = snoise_grad(float3(rnd * 2378.34, time * 0.8, 0));

        // Triangle animation
        float t_anim = 1 + param * 60;
        float3 t_p0 = lerp(center, p0, t_anim);
        float3 t_p1 = lerp(center, p1, t_anim);
        float3 t_p2 = lerp(center, p2, t_anim);

        // Cube animation
        float c_anim = saturate(param * 4 - 3);

        if (c_anim < 1)
        {
            // Cube size
            float3 c_size = float2(1 - c_anim, 1 + c_anim * 4).xyx;
            c_size *= 0.05 * saturate(1 + snoise.w * 2);

            // Cube position
            float3 c_p = center + snoise.xyz * 0.02;

            // Vertices (with triangle -> cube defromation)
            float c_param = saturate(param * 2 - 0.5);
            float4 c_p0 = CubePoint(t_p0, c_p, float3(-1, -1, -1), c_size, c_param);
            float4 c_p1 = CubePoint(t_p0, c_p, float3(+1, -1, -1), c_size, c_param);
            float4 c_p2 = CubePoint(t_p0, c_p, float3(-1, +1, -1), c_size, c_param);
            float4 c_p3 = CubePoint(t_p1, c_p, float3(+1, +1, -1), c_size, c_param);
            float4 c_p4 = CubePoint(t_p1, c_p, float3(-1, -1, +1), c_size, c_param);
            float4 c_p5 = CubePoint(t_p1, c_p, float3(+1, -1, +1), c_size, c_param);
            float4 c_p6 = CubePoint(t_p2, c_p, float3(-1, +1, +1), c_size, c_param);
            float4 c_p7 = CubePoint(t_p2, c_p, float3(+1, +1, +1), c_size, c_param);

            // Output the vertices
            half3 color = Hue2RGB(rnd);
            outStream.Append(SetGeoOut(c_p2, n0, color, c_param));
            outStream.Append(SetGeoOut(c_p0, n0, color, c_param));
            outStream.Append(SetGeoOut(c_p6, n2, color, c_param));
            outStream.Append(SetGeoOut(c_p4, n1, color, c_param));
            outStream.RestartStrip();

            color = Hue2RGB(rnd + 0.1);
            outStream.Append(SetGeoOut(c_p1, n0, color, c_param));
            outStream.Append(SetGeoOut(c_p3, n1, color, c_param));
            outStream.Append(SetGeoOut(c_p5, n1, color, c_param));
            outStream.Append(SetGeoOut(c_p7, n2, color, c_param));
            outStream.RestartStrip();

            color = Hue2RGB(rnd + 0.2);
            outStream.Append(SetGeoOut(c_p0, n0, color, c_param));
            outStream.Append(SetGeoOut(c_p1, n0, color, c_param));
            outStream.Append(SetGeoOut(c_p4, n1, color, c_param));
            outStream.Append(SetGeoOut(c_p5, n1, color, c_param));
            outStream.RestartStrip();

            color = Hue2RGB(rnd + 0.3);
            outStream.Append(SetGeoOut(c_p3, n1, color, c_param));
            outStream.Append(SetGeoOut(c_p2, n0, color, c_param));
            outStream.Append(SetGeoOut(c_p7, n2, color, c_param));
            outStream.Append(SetGeoOut(c_p6, n2, color, c_param));
            outStream.RestartStrip();

            color = Hue2RGB(rnd + 0.4);
            outStream.Append(SetGeoOut(c_p1, n0, color, c_param));
            outStream.Append(SetGeoOut(c_p0, n0, color, c_param));
            outStream.Append(SetGeoOut(c_p3, n1, color, c_param));
            outStream.Append(SetGeoOut(c_p2, n1, color, c_param));
            outStream.RestartStrip();

            color = Hue2RGB(rnd + 0.5);
            outStream.Append(SetGeoOut(c_p4, n1, color, c_param));
            outStream.Append(SetGeoOut(c_p5, n1, color, c_param));
            outStream.Append(SetGeoOut(c_p6, n2, color, c_param));
            outStream.Append(SetGeoOut(c_p7, n2, color, c_param));
            outStream.RestartStrip();
        }
    }
    else
    {
        // Triangle animation
        float t_param = saturate(1 - param * 40);
        if (t_param > 0)
        {
            outStream.Append(SetTriangleGeoOut(center, p0, t_param, n0));
            outStream.Append(SetTriangleGeoOut(center, p1, t_param, n1));
            outStream.Append(SetTriangleGeoOut(center, p2, t_param, n2));
            outStream.RestartStrip();
        }
    }
}

// Fragment phase
half4 Fragment(Varyings input) : SV_Target
{
    return half4(input.color, 1);
}
