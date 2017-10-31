Shader "Voxelizer"
{
    Properties
    {
        _Voxelize("Voxelize", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex Vertex
            #pragma geometry Geometry
            #pragma fragment Fragment
            #include "Voxelizer.cginc"
            ENDCG
        }
    }
}
