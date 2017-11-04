// Kino/Streak - Anamorphic lens flare effect for Unity
// https://github.com/keijiro/KinoStreak

Shader "Hidden/Kino/Streak"
{
    Properties
    {
        _MainTex("", 2D) = ""{}
        _HighTex("", 2D) = ""{}
        _Color("", Color) = (1, 1, 1)
        [Gamma] _Intensity("", Float) = 1
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        // Prefilter
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_prefilter
            #include "Streak.cginc"
            ENDCG
        }

        // Downsampler
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_down
            #include "Streak.cginc"
            ENDCG
        }

        // Upsampler
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_up
            #include "Streak.cginc"
            ENDCG
        }

        // Final composition
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_composite
            #include "Streak.cginc"
            ENDCG
        }
    }
}
