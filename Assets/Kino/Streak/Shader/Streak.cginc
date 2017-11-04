// Kino/Streak - Anamorphic lens flare effect for Unity
// https://github.com/keijiro/KinoStreak

#include "UnityCG.cginc"

sampler2D _MainTex;
float4 _MainTex_TexelSize;

sampler2D _HighTex;
float4 _HighTex_TexelSize;

float _Threshold;
float _Stretch;
float _Intensity;
half3 _Color;

// Prefilter: Shrink horizontally and apply threshold.
half4 frag_prefilter(v2f_img i) : SV_Target
{
    // Actually this should be 1, but we assume you need more blur...
    const float vscale = 1.5;
    const float dy = _MainTex_TexelSize.y * vscale / 2;

    half3 c0 = tex2D(_MainTex, float2(i.uv.x, i.uv.y - dy));
    half3 c1 = tex2D(_MainTex, float2(i.uv.x, i.uv.y + dy));
    half3 c = (c0 + c1) / 2;

    float br = max(c.r, max(c.g, c.b));
    c *= max(0, br - _Threshold) / max(br, 1e-5);

    return half4(c, 1);
}

// Downsampler
half4 frag_down(v2f_img i) : SV_Target
{
    // Actually this should be 1, but we assume you need more blur...
    const float hscale = 1.25;
    const float dx = _MainTex_TexelSize.x * hscale;

    float u0 = i.uv.x - dx * 5;
    float u1 = i.uv.x - dx * 3;
    float u2 = i.uv.x - dx * 1;
    float u3 = i.uv.x + dx * 1;
    float u4 = i.uv.x + dx * 3;
    float u5 = i.uv.x + dx * 5;

    half3 c0 = tex2D(_MainTex, float2(u0, i.uv.y));
    half3 c1 = tex2D(_MainTex, float2(u1, i.uv.y));
    half3 c2 = tex2D(_MainTex, float2(u2, i.uv.y));
    half3 c3 = tex2D(_MainTex, float2(u3, i.uv.y));
    half3 c4 = tex2D(_MainTex, float2(u4, i.uv.y));
    half3 c5 = tex2D(_MainTex, float2(u5, i.uv.y));

    // Simple box filter
    half3 c = (c0 + c1 + c2 + c3 + c4 + c5) / 6;

    return half4(c, 1);
}

// Upsampler
half4 frag_up(v2f_img i) : SV_Target
{
    half3 c0 = tex2D(_MainTex, i.uv) / 4;
    half3 c1 = tex2D(_MainTex, i.uv) / 2;
    half3 c2 = tex2D(_MainTex, i.uv) / 4;
    half3 c3 = tex2D(_HighTex, i.uv);
    return half4(lerp(c3, c0 + c1 + c2, _Stretch), 1);
}

// Final composition
half4 frag_composite(v2f_img i) : SV_Target
{
    half3 c0 = tex2D(_MainTex, i.uv) / 4;
    half3 c1 = tex2D(_MainTex, i.uv) / 2;
    half3 c2 = tex2D(_MainTex, i.uv) / 4;
    half3 c3 = tex2D(_HighTex, i.uv);
    half3 cf = (c0 + c1 + c2) * _Color * _Intensity * 5;
    return half4(cf + c3, 1);
}
