Shader "Voxelizer Base"
{
	Properties
    {
		_Color("Color", Color) = (1, 1, 1, 1)
		_Glossiness("Smoothness", Range(0, 1)) = 0
		_Metallic("Metallic", Range(0, 1)) = 0
	}
	SubShader
    {
		Tags { "RenderType"="Opaque" }
		
		CGPROGRAM

		#pragma surface surf Standard addshadow fullforwardshadows
		#pragma target 3.0

        #include "Common.cginc"

		struct Input { float3 worldPos; };

        float4 _EffectVector;

		half4 _Color;
		half _Glossiness;
		half _Metallic;

		void surf(Input IN, inout SurfaceOutputStandard o)
        {
            float param = 1 - dot(_EffectVector.xyz, IN.worldPos) + _EffectVector.w;

            clip(-param);

			o.Albedo = _Color.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = _Color.a;
		}

		ENDCG
	}
	FallBack "Diffuse"
}
