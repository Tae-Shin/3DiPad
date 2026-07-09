Shader "Unlit/display_+"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _CenterX ("Cross Center X (px)", Int) = 820
        _CenterY ("Cross Center Y (px)", Int) = 1180
        _Thickness ("Cross Thickness (px)", Int) = 6
        _CrossColor ("Cross Color", Color) = (0, 0, 0, 1)
        _BackColor ("Background Color", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "include_rev2.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            int _CenterX;
            int _CenterY;
            int _Thickness;
            fixed4 _CrossColor;
            fixed4 _BackColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = _BackColor;

                int2 pos = i.uv * _DisplayResolution;

                int2 center = int2(_CenterX, _CenterY);
                int half0 = _Thickness / 2;

                // 縦棒: x が center.x を挟んで _Thickness px
                bool vBar = (pos.x >= center.x - half0 && pos.x < center.x + half0);
                // 横棒: y が center.y を挟んで _Thickness px
                bool hBar = (pos.y >= center.y - half0 && pos.y < center.y + half0);

                if (vBar || hBar)
                {
                    col = _CrossColor;
                }
                return col;
            }
            ENDCG
        }
    }
}