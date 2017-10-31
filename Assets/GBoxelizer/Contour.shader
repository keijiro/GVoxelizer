Shader "Hidden/Contour"
{
    Properties
    {
        _MainTex("", 2D) = ""{}
        _Color0("", Color) = (0, 0, 0)
        _Color1("", Color) = (1, 1, 1)
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float2 _MainTex_TexelSize;

    half3 _Color0;
    half3 _Color1;

    float _Threshold1;
    float _Threshold2;

    fixed4 frag(v2f_img i) : SV_Target
    {
        float3 duv = float3(_MainTex_TexelSize.xy, 0);

        // Neighbor samples
        fixed3 c0 = tex2D(_MainTex, i.uv         ).xyz; // TL
        fixed3 c1 = tex2D(_MainTex, i.uv + duv.xy).xyz; // BR
        fixed3 c2 = tex2D(_MainTex, i.uv + duv.xz).xyz; // TR
        fixed3 c3 = tex2D(_MainTex, i.uv + duv.zy).xyz; // BL

        // Roberts cross operator
        fixed3 g1 = c1 - c0;
        fixed3 g2 = c3 - c2;
        half g = sqrt(dot(g1, g1) + dot(g2, g2));

        // Thresholding
        g = saturate((g - _Threshold1) / (_Threshold2 - _Threshold1));

        return half4(lerp(_Color0, _Color1, g), g);
    }

    ENDCG

    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            ENDCG
        }
    }
}
