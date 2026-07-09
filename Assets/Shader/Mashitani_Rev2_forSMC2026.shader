Shader "Unlit/Mashitani_Rev2_forSMC2026"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Scale("Scale", float) = 1.0
		_Width("Width", float) = 1.77777
		_Height("Height", float) = 1.0
		_IsSBS("IsSBS", Range(0, 1)) = 1
		_Shift("Shift", float) = 1.0
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

            // 両目の位置[x, y, zs]
            float3 _PosL;
			float3 _PosR;

            // 交差するサブピクセル数
            float _ProximityDot;

            // よくわからんやつ
            int _BrightnessIndex;

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
            float _Scale;
			float _Width;
			float _Height;
            float _Shift;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            struct subpixel
			{
				float2 pos;
			};

			struct pixel
			{
				float2 pos;
				subpixel r, g, b;
			};

            //---------------------------------------------------------------------------
            // 回転ずれ補正アルゴリズム
            //---------------------------------------------------------------------------
            // 回転計算後の値を格納する構造体
            struct RotationParams
            {
                float2 newMRatio;
                float newM;
                float newK;
                float newOVD;
            };
            // パラメータを更新する関数
            RotationParams CalcRotationParams(float theta, float2 baseMRatio, float baseM, float baseK, float baseOVD, int screenOrientation)
            {
                RotationParams result;

                // 傾斜角の計算
                float baseT = atan(float(baseMRatio.x)/float(baseMRatio.y * -3.0f)); // バリアの設計傾斜角
                float t = baseT + radians(theta); // 合計の傾斜角 t (描画の投影に使用)

                // 傾斜角による水平ピッチの補正
                float designCos = cos(baseT);
                float physicalCos = cos(t);
                if (abs(physicalCos) < 0.0001) physicalCos = 1.0;

                // 物理空間への変換 (Aspect Ratio 1:3 補正)
                // サブピクセル数を物理的なピクセル幅に変換
                float physBaseX = baseMRatio.x / 3.0;
                float physBaseY = baseMRatio.y;        // Yはそのまま (1行=1単位)

                // 回転行列の適用 (物理空間での回転)
                // 時計回りを正とする（正のthetaで傾斜角が増加）
                float rad = radians(-theta);
                float cosVal = cos(rad);
                float sinVal = sin(rad);

                // 物理ベクトルを回転 (時計回りが正)
                float physNewX = physBaseX * cosVal + physBaseY * sinVal;
                float physNewY = -physBaseX * sinVal + physBaseY * cosVal;

                // ---------------------------------------------------------------
                // バリア線の傾斜比 _MRatio 再計算
                // ---------------------------------------------------------------
                // サブピクセル単位に戻す
                float newX = physNewX * 3.0;
                float newY = physNewY;
                result.newMRatio = float2(newX, newY);

                // ---------------------------------------------------------------
                // 傾き_Mの再計算
                // ---------------------------------------------------------------
                result.newM = 0.0f;
                if (abs(newX) > 0.00001)
                {
                    bool isLandscape = (screenOrientation >= 3); // LandscapeLeft=3, LandscapeRight=4
                    
                    if (isLandscape)
                    {
                        // 横置き: 3 * y / x
                        result.newM = 3.0 * newY / newX;
                    }
                    else
                    {
                        // 縦置き: x / (3 * y)
                        result.newM = newX / (3.0 * newY);
                    }
                }

                // ---------------------------------------------------------------
                // 視差画像を構成する水平ピッチ_Kの再計算
                // ---------------------------------------------------------------
                float Normal_k = baseK * designCos;    // 法線方向の_k 計算
                result.newK = Normal_k / physicalCos;  // 傾斜角θ+Φのときの_k 計算

                // ---------------------------------------------------------------
                // 最適視距離_OVDの再計算
                // ---------------------------------------------------------------
                result.newOVD = baseOVD * (baseK / result.newK);

                return result;
            }
            // 現在の_Phiに基づいて回転後のパラメータを取得する関数
            RotationParams GetCurrentRotationParams()
            {
                return CalcRotationParams(_Phi, _MRatio, _M, _k, _OVD,_ScreenOrientation);
            }
            // ---------------------------------------------------------------


            // 屈折を考慮したUV座標
            float2 RefractionUV(float3 eyePos, float2 pos)
			{
				//܍lUVʒu
				float2 pixPos = (pos - 0.5f) * _DisplayResolution * _PixelPitch;
				float sub;//��������s�N�Z�������܂ł̐�������[mm]
				float theta1;//���܊p[rad]
				float theta2;//���ˊp[rad]
				float delta_p;//���ܗ��l�������ꍇ�̂����[mm]
				//delta_p�̓��o�Adelta_p�͕K�����ƂȂ�
				sub = sqrt((eyePos.x - pixPos.x) * (eyePos.x - pixPos.x) + (eyePos.y - pixPos.y) * (eyePos.y - pixPos.y));
				float x = NewtonMethod(0, sub, eyePos.z);
				theta2 = atan((sub - x) / eyePos.z);
				theta1 = asin(sin(theta2) / _N);
				delta_p = _Gap * tan(theta1) * ((cos(theta1) - cos(theta2)) / cos(theta2));
				float deltaX, deltaY;
				deltaX = delta_p * (pixPos.x - eyePos.x) / sub;
				deltaY = delta_p * (pixPos.y - eyePos.y) / sub;
				float2 RefPos;
				RefPos.x = pixPos.x + deltaX;
				RefPos.y = pixPos.y + deltaY;
				float2 RefPosUV;
				RefPosUV = RefPos / _DisplayResolution / _PixelPitch + 0.5f;
				return RefPosUV;
			}

            // 両目のディスプレイ上の目の位置
            float2 DisplayPos(float3 eyePos) {
				float2 temp = float2(eyePos.x, eyePos.y);
				float2 displayPos = temp / _DisplayResolution / _PixelPitch + 0.5f;
				return displayPos;
			}

            // 今見ているピクセル情報設定
            pixel InitPixel(int2 pixelPos)
            {
                // ------- pixel coordinate origin is display center  -------
                // -----------------------------------------------------------
                // |                           |                             |
                // |                           |                             |
                // |                           |                             |
                // |     (-3,1) (-2,1)  (-1,1) | (0,1) (1,1) (2,1)           |
                // |     (-3,0) (-2,0)  (-1,0) | (0,0) (1,0) (2,0)           |
                // |---------------------------|-----------------------------|
                // |     (-3,-1)(-2,-1) (-1,-1)| (0,-1)(1,-1) (2,-1)         |
                // |     (-3,-2)(-2,-2) (-1,-2)| (0,-2)(1,-2) (2,-2)         |
                // |                           |                             |
                // |                           |                             |
                // |                           |                             |
                // -----------------------------------------------------------
                // ------------------ RGBsubpixel center pos -----------------
                // ------------------------------------------------------------
                // |                   |                   |                  |
                // |                   |                   |                  |
                // |         R         |         G         |         B        |
                // |<-------->------------------->------------------->        |
                // |    1/6            |   1/2             |   5/6            |
                // ------------------------------------------------------------
                pixel p;
                p.pos = pixelPos + float2(0.5f, 0.5f);
                // r,g,bサブピクセルの2D座標設定[mm]
                // _DisplayResolution * _PixelPitch / 2.0f → ディスプレイの中心2D座標[mm]取得（ここを原点）
                if(_ScreenOrientation >= 3){
                    p.r.pos = float2(pixelPos.x + 1.0f / 6.0f, pixelPos.y + 0.5f) * _PixelPitch - _DisplayResolution * _PixelPitch / 2.0f;
                    p.g.pos = float2(pixelPos.x + 1.0f / 2.0f, pixelPos.y + 0.5f) * _PixelPitch - _DisplayResolution * _PixelPitch / 2.0f;
                    p.b.pos = float2(pixelPos.x + 5.0f / 6.0f, pixelPos.y + 0.5f) * _PixelPitch - _DisplayResolution * _PixelPitch / 2.0f;
                }else{
                    p.r.pos = float2(pixelPos.x + 0.5f, pixelPos.y + 5.0f / 6.0f) * _PixelPitch - _DisplayResolution * _PixelPitch / 2.0f;
                    p.g.pos = float2(pixelPos.x + 0.5f, pixelPos.y + 1.0f / 2.0f) * _PixelPitch - _DisplayResolution * _PixelPitch / 2.0f;
                    p.b.pos = float2(pixelPos.x + 0.5f, pixelPos.y + 1.0f / 6.0f) * _PixelPitch - _DisplayResolution * _PixelPitch / 2.0f;
                }
                if(_ScreenOrientation % 2 == 0) {
                    float2 t = p.r.pos;
                    p.r.pos = p.b.pos;
                    p.b.pos = t;
                }
                return p;
            }

            // OVD上のサイクロプスの目の座標[mm]推定
            float3 CalcEyePosOnOVD(float3 eyePos, float2 subpixelPos, float newOVD)
            {
                float t = newOVD / eyePos.z;  // 奥行の比
                // 今見ているサブピクセルの2D座標[mm]
                float x = subpixelPos.x;
                float y = subpixelPos.y;
                // return float3((1.0f - t) * x + t * eyePos.x, (1.0f - t) * y + t * eyePos.y, _OVD);
                return float3((1.0f - t) * x + t * eyePos.x + _Origin, (1.0f - t) * y + t * eyePos.y, newOVD);
            }

            // 視差画像生成
            float Draw(subpixel sp, subpixel rsp, float3 clopeanEye, float leftImage, float rightImage) 
            { 
                // 現在の回転パラメータを取得
                RotationParams rotParams = GetCurrentRotationParams();
                float2 newMRatio = rotParams.newMRatio;
                float newM = rotParams.newM;
                float newK = rotParams.newK;
                float newOVD = rotParams.newOVD;

                // 初期化
                float subpixelValue = 0;

                // 丸め込み用の微小値
                float eps = 1e-6;

                // ディスプレイ上の視差画像を構成する水平ピッチk の中心点初期化
                float k_center = 0;
                
                // サイクロプスの目の位置をOVD上に投影してk_centerOnOVDからの移動量を計算
                float3 InterocularPosOnOVD = CalcEyePosOnOVD(clopeanEye, sp.pos, newOVD);

                // サイクロプスの目の位置に合わせて、k_centerを更新(幾何学的に移動方向は反対なのでマイナス)
                float dx = - ((InterocularPosOnOVD.x - ((InterocularPosOnOVD.y) / newM)) * (newK / (2.0f * _E)));

                // サイクロプスの目の位置にあわせて，k_centerを更新
                k_center = k_center + dx;

                // 視差画像を構成する水平ピッチk の中心点を現在見ているサブピクセルと同じ行まで移動(傾き1/_Mに沿ってy=0に投影したX座標)
                k_center = k_center + (sp.pos.y / newM);

                // sp.pos.xがk_centerからどれだけ離れているかを水平ピッチkで割って，何倍か計算(丸め込み : 四捨五入)
                int n = (int)round((sp.pos.x - k_center) / newK);

                // k_centerを更新
                k_center = k_center + (float)n * newK;

                // 左目・右目テクスチャの割り当て
                if (sp.pos.x > k_center + eps) {      // 左目
                    subpixelValue = leftImage;
                }
                else if (sp.pos.x < k_center - eps){  // 右目
                    subpixelValue = rightImage;
                }

                // return
				return subpixelValue;
            }

            // 増谷式GenerateImage
            float4 GenerateImage(float3 leftEye, float3 rightEye, float2 uv)
            {
                // サイクロプスの目(両目の中心位置)
                float3 InterocularPos = (leftEye + rightEye) / 2.0f;

                // ズーム
				float inverse = 1.0f / _Scale;
				float2 scaledUV = uv * inverse;
				float offset = ((1.0f - inverse) - 0.5f) + (inverse / 2.0f);
				scaledUV += float2(offset, offset);

                // アスペクト比
				float2 modifiedUV = float2(scaledUV.x * _Width, scaledUV.y * _Height);
				float2 UVoffset = float2(abs(1 - _Width) / 2, 0);
				modifiedUV -= UVoffset;

                // 視差量シフト
				float horizontalShift = _Shift / (_DisplayResolution.x * 3);

                float4 leftImage;
				float4 rightImage;
				float BlackOffset;

                // テクスチャがSBSかチェック
                if (_IsSBS == 1)
				{
					float2 L = float2(modifiedUV.x / 2, modifiedUV.y);
					float2 R = float2(modifiedUV.x / 2 + 0.5, modifiedUV.y);
					L.x += horizontalShift;
					R.x -= horizontalShift;

					leftImage = tex2D(_LTex, L);
					rightImage = tex2D(_RTex, R);
					BlackOffset = float(abs(horizontalShift) + (1 - (1.0 / _Width)) / 2) * 2;
				}
				else
				{
					float2 L = float2(modifiedUV.x, modifiedUV.y);
					float2 R = float2(modifiedUV.x, modifiedUV.y);
					
					L.x += horizontalShift;
					R.x -= horizontalShift;
					
					if(_Reversal == 0)
					{
						leftImage = tex2D(_LTex, L);
						rightImage = tex2D(_RTex, R);
					}
					else
					{
						leftImage = tex2D(_RTex, float2(1.0 - L.x, L.y));
						rightImage = tex2D(_LTex, float2(1.0 - R.x, L.y));
					}

					BlackOffset = float(abs(horizontalShift) + (1 - (1.0 / _Width)) / 2);
				}

                float2 LblackUVStart = float2(0, 0);
				float2 LblackUVEnd = float2(BlackOffset, 1);
				float2 RblackUVStart = float2(1 - BlackOffset, 0);
				float2 RblackUVEnd = float2(1, 1);

                // 両端黒く塗りつぶす
                if (uv.x <= LblackUVEnd.x && uv.y <= LblackUVEnd.y)
				{
					leftImage = float4(0, 0, 0, 1);
					rightImage = float4(0, 0, 0, 1);
				}
				if (uv.x >= RblackUVStart.x && uv.y <= RblackUVEnd.y)
				{
					leftImage = float4(0, 0, 0, 1);
					rightImage = float4(0, 0, 0, 1);
				}

                // 初期カラー
                float4 rgba = float4(0, 0, 0, 1);

                // uv * _DisplayResolution → 今見ているピクセル座標[pixel]
                pixel p = InitPixel(uv * _DisplayResolution); // pixel インスタンス化
                pixel rp = InitPixel(RefractionUV(InterocularPos,uv) * _DisplayResolution);

                // カラーセット
                rgba.r = Draw(p.r, rp.r, InterocularPos, leftImage.r, rightImage.r);
                rgba.g = Draw(p.g, rp.g, InterocularPos, leftImage.g, rightImage.g);
                rgba.b = Draw(p.b, rp.b, InterocularPos, leftImage.b, rightImage.b);
                
                // 両目描画
                // if (_MarkerFlag == 0) {
				// 	if (sqrt((DisplayPos(leftEye).x - uv.x) * (DisplayPos(leftEye).x - uv.x) + (DisplayPos(leftEye).y - uv.y) * (DisplayPos(leftEye).y - uv.y)) < 0.01f) {
				// 		return float4(0, 0, 1, 1);
				// 	}
				// 	else if (sqrt((DisplayPos(rightEye).x - uv.x) * (DisplayPos(rightEye).x - uv.x) + (DisplayPos(rightEye).y - uv.y) * (DisplayPos(rightEye).y - uv.y)) < 0.01f) {
				// 		return float4(1, 0, 0, 1);
				// 	}
				// 	else {
				// 		return rgba;
				// 	}
				// }
				// else {
				// 	return rgba;
				// }

                // 上端から 900px の領域は黒く塗りつぶす
                if (int2(uv * _DisplayResolution).y > 1460){
                    rgba = float4(0, 0, 0, 1);
                }

                // 下端から 400px の領域は黒く塗りつぶす
                if (int2(uv * _DisplayResolution).y < 400){
                    rgba = float4(0, 0, 0, 1);
                }

                return rgba;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // サイクロプスの目(両目の中心点)を用いて視差画像を構成
                return GenerateImage(_PosL, _PosR, i.uv);
            }
            ENDCG
        }
    }
}
