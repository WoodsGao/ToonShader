Shader "PostProcessing/EdgeDetect"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SampleScale("SampleScale", Float) = 1.0
        _NormalEdgeFactor("NormalEdgeFactor(min, max, intensity)", Vector) = (0,1,1,1)
        _DepthEdgeFactor("DepthEdgeFactor(min, max, intensity)", Vector) = (0,1,1,1)
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            float _SampleScale;
            float4 _NormalEdgeFactor, _DepthEdgeFactor; 
            sampler2D _MainTex, _CameraDepthNormalsTexture;
            float4 _MainTex_TexelSize;
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv[5] : TEXCOORD0;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                float2 uv = v.uv;
                float2 offset = _MainTex_TexelSize.xy * _SampleScale;
                o.uv[0] = uv;

                o.uv[1] = uv + offset * float2(1, 1);
                o.uv[2] = uv + offset * float2(1, -1);
                o.uv[3] = uv + offset * float2(-1, 1);
                o.uv[4] = uv + offset * float2(-1, -1);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 color = tex2D(_MainTex, i.uv[0]);
                float2 normals[5];
                float depths[5];
                for (int index = 0; index < 5; index++)
                {
                    float4 values = tex2D(_CameraDepthNormalsTexture, i.uv[index]);
                    normals[index] = values.xy;
                    depths[index] = DecodeFloatRG(values.zw);
                }
                float2 normalSobel_ = abs(normals[1]+normals[2]-normals[3]-normals[4]) + abs(normals[1]-normals[2]+normals[3]-normals[4]);
                float normalSobel = 0.5*(normalSobel_.x + normalSobel_.y);

                float depthSobel = abs(depths[1]+depths[2]-depths[3]-depths[4])
                + abs(depths[1]-depths[2]+depths[3]-depths[4]);

                float edge = 0;
                edge += smoothstep(_NormalEdgeFactor.x, _NormalEdgeFactor.y, normalSobel) * _NormalEdgeFactor.z;
                edge += smoothstep(_DepthEdgeFactor.x, _DepthEdgeFactor.y, depthSobel) * _DepthEdgeFactor.z;
                edge = saturate(edge);
                
                color.rgb = lerp(color.rgb, float3(0,0,0), edge);
                return color;
            }
            ENDCG
        }
    }
}
