Shader "Toon/ToonShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _1st_ShadeMap ("1st Shade Map", 2D) = "white" {}
        _1st_ShadeColor ("1st Shade Color", Color) = (1,1,1,1)
        _2nd_ShadeMap ("2nd Shade Map", 2D) = "white" {}
        _2nd_ShadeColor ("2nd Shade Color", Color) = (1,1,1,1)
        _ShadowRecvMask ("Shadow Recv Mask", 2D) = "white" {}
        _MatCapMask ("MatCap Mask", 2D) = "black" {}
        _MatCapTex ("MatCap Tex", 2D) = "white" {}
        _MatCapColor ("MatCap Color", Color) = (1,1,1,1)
        _SpMask ("Specular Mask", 2D) = "black" {}
        _SpTex ("Specular Tex", 2D) = "white" {}
        _SpColor ("Specular Color", Color) = (1,1,1,1)
        _SpPower ("Specular Power", Float) = 5
        _RimColor ("Rim Color", Color) = (0,0,0,0)
        _RimStep ("Rim Step", Float) = 0.3
        _RimPower ("Rim Power", Float) = 5
        _NormalFixIntensity ("Normal Fix Intensity", Vector) = (0,0,0,0)

        _ShadeStep ("Shade Steps", Vector) = (0.8,0.5,0,0)

        _IsEye ("Is Eye", Int) = 0
        _EyeIOR ("EyeIOR", Range(0,1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" 
        "LightMode"="ForwardBase" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma multi_compile_fwdbase_fullshadows

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            sampler2D _MainTex, _1st_ShadeMap, _2nd_ShadeMap, _SpMask, _SpTex, _MatCapMask, _MatCapTex, _ShadowRecvMask;
            float _RimPower, _RimStep, _SpPower, _EyeIOR;
            float4 _ShadeStep, _RimColor, _1st_ShadeColor, _2nd_ShadeColor, _MatCapColor, _SpColor, _BaseColor, _NormalFixIntensity;
            int _IsEye;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord0 : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float4 posWorld : TEXCOORD1;
                float3 normalDir : TEXCOORD2;
                float3 tangentDir : TEXCOORD3;
                float3 bitangentDir : TEXCOORD4;
                float mirrorFlag : TEXCOORD5;
                LIGHTING_COORDS(6,7)
                UNITY_FOG_COORDS(8)

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.uv0 = v.texcoord0;
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.tangentDir = normalize( mul( unity_ObjectToWorld, float4( v.tangent.xyz, 0.0 ) ).xyz );
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                float3 lightColor = _LightColor0.rgb;
                o.pos = UnityObjectToClipPos( v.vertex );
                //v.2.0.7 Detection of the inside the mirror (right or left-handed) o.mirrorFlag = -1 then "inside the mirror".
                float3 crossFwd = cross(UNITY_MATRIX_V[0], UNITY_MATRIX_V[1]);
                o.mirrorFlag = dot(crossFwd, UNITY_MATRIX_V[2]) < 0 ? 1 : -1;
                //
                UNITY_TRANSFER_FOG(o,o.pos);
                TRANSFER_VERTEX_TO_FRAGMENT(o)
                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                i.normalDir = normalize(i.normalDir);
                float3x3 TBN = float3x3( i.tangentDir, i.bitangentDir, i.normalDir);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
                float2 uv = i.uv0;
                //v.2.0.6
                float3 normalDir = i.normalDir;
                // return float4(normalDir*0.5+0.5, 1);

                // fix normal for face
                float3 faceXDir = mul(UNITY_MATRIX_M, float4(0,0,1,0)).xyz;
                float3 faceYDir = mul(UNITY_MATRIX_M, float4(1,0,0,0)).xyz;
                float3 faceZDir = mul(UNITY_MATRIX_M, float4(0,1,0,0)).xyz;
                // normalDir = lerp(normalDir, faceYDir, 1);
                normalDir -= dot(faceXDir, normalDir) * faceXDir * _NormalFixIntensity.x;
                normalDir -= dot(faceYDir, normalDir) * faceYDir * _NormalFixIntensity.y;
                normalDir = normalize(normalDir);
                // return float4(normalDir*0.5+0.5, 1);

                // eye inner
                float3 cornealNormalDir = normalDir;
                if (_IsEye) {
                    normalDir = reflect(normalDir, faceZDir);
                    float3 refractDir = lerp(-viewDir, -cornealNormalDir, _EyeIOR);
                    float height = 1-length(uv-0.5)*2.0;
                    height *= height;
                    float3 refractPath = refractDir * height / dot(refractDir, faceZDir);
                    uv += 0.05 * float2(dot(refractPath, i.tangentDir), dot(refractPath, i.bitangentDir));
                    // return float4(uv,0,1);
                }

                UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);

                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 lightColor = _LightColor0.rgb;
                float3 halfDir = normalize(viewDir+lightDir);

                float4 finalColor = tex2D(_MainTex, uv) * _BaseColor;
                // return finalColor;

                float4 shade1 = tex2D(_1st_ShadeMap, uv) * _1st_ShadeColor;
                float4 shade2 = tex2D(_2nd_ShadeMap, uv) * _2nd_ShadeColor;

                float halfLambert = 0.5*dot(normalDir,lightDir)+0.5; // Half Lambert

                float systemShadowsLevel = (attenuation*0.5)+0.5;
                systemShadowsLevel = systemShadowsLevel > 0.001 ? systemShadowsLevel : 0.0001;
                float shadowRecv = tex2D(_ShadowRecvMask, uv).r;
                float shadingGrade = lerp( halfLambert, halfLambert*saturate(systemShadowsLevel), shadowRecv);


                finalColor = lerp(shade1, finalColor, step(_ShadeStep.x, shadingGrade));
                finalColor = lerp(shade2, finalColor, step(_ShadeStep.y, shadingGrade));


                // Specular
                float specular = 0.5*dot(halfDir, normalDir)+0.5;
                float4 specularColor = tex2D(_SpTex, uv);
                specularColor.rgb *= lightColor;
                float specularMask = tex2D(_SpMask, uv).r;
                specular = pow(specular, _SpPower) * specularMask;

                // finalColor.rgb = lerp(finalColor.rgb, specularColor * _SpColor.rgb, specular * _SpColor.a);
                finalColor.rgb += specularColor.rgb * specular * _SpColor.rgb * _SpColor.a;


                // Rim Light
                float rimIntensity = saturate(1.0 - dot(normalDir, viewDir));
                rimIntensity = pow(rimIntensity, _RimPower);
                finalColor.rgb += _RimColor.rgb * _RimColor.a * smoothstep(0, _RimStep, rimIntensity);


                // MatCap
                float3 normalVS = mul(UNITY_MATRIX_V, float4(normalDir, 0)).xyz;
                float matCapMask = tex2D(_MatCapMask, uv).r;
                float4 matCapColor = tex2D(_MatCapTex, normalVS.xy*0.5+0.5);
                finalColor.rgb *= lerp(float3(1,1,1), matCapColor.rgb * _MatCapColor.rgb, matCapMask * _MatCapColor.a);

                return finalColor;
                return float4(normalVS,1);
            }
            ENDCG
        }
    }
    Fallback"Specular"
}
