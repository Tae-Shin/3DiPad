Shader "Unlit/StripePattern_v1"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
			#include "include.cginc"
			#include "viewingArea.cginc"

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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            
            //画素番号決定関数（垂直型）
            int3 PixelNumberVertical(int2 pix)
            {
                int3 p;
                if (_ScreenOrientation >= 3)
                {
                    pix.x *= 3;
                    p.r = ((_PatternNum - _MRatio.y) * pix.x) % _PatternNum;//画素値の計算導出
                    p.g = ((_PatternNum - _MRatio.y) * (pix.x + 1)) % _PatternNum;
                    p.b = ((_PatternNum - _MRatio.y) * (pix.x + 2)) % _PatternNum;
                }
                else if (_ScreenOrientation < 3)
                {
                    pix.y *= 3;
                    p.b = (_MRatio.x * pix.y) % _PatternNum;          //画素値の計算導出
                    p.g = (_MRatio.x * (pix.y + 1)) % _PatternNum;
                    p.r = (_MRatio.x * (pix.y + 2)) % _PatternNum;
                }
                p.r += (p.r < 0) ? _PatternNum : 0;
                p.g += (p.g < 0) ? _PatternNum : 0;
                p.b += (p.b < 0) ? _PatternNum : 0;
                if (_ScreenOrientation % 2 == 0) Swap(p.r, p.b);
                return p;
            }

            // ストライプパターン決定関数
            float StripePattern(int num, float leftImage, float rightImage)
            {
                if (num == 0 || num == 1) return leftImage;
                else return rightImage;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 初期カラー
                float4 rgba = float4(0, 0, 0, 1);

                // 左右画像のテクスチャ取得
                float4 leftImage = tex2D(_LTex, i.uv);
				float4 rightImage = tex2D(_RTex, i.uv);
                
                // サブピクセル番号割り当て
                int3 num = PixelNumberVertical(i.uv * _DisplayResolution);

                // テクスチャ割り当て
                rgba.r = StripePattern(num.r, leftImage.r, rightImage.r);
                rgba.g = StripePattern(num.g, leftImage.g, rightImage.g);
                rgba.b = StripePattern(num.b, leftImage.b, rightImage.b);

                return rgba;
            }
            ENDCG
        }
    }
}
