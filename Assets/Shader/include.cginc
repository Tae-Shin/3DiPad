float _Origin;

//適視距離[mm]
float _OVD;

//ドット領域幅[mm]
float _F;

//眼間距離[mm]
float _E;

//ディスプレイ解像度[px x px]
float2 _DisplayResolution;

//バリア傾斜角[subpx]
float _M;
int2 _MRatio;

//パターン数
int _PatternNum;

//ディスプレイの向き
int _ScreenOrientation;

//ピクセルピッチ
float _PixelPitch;

//両眼の位置[mm]
float3 _PosL;
float3 _PosR;

//開口率
float _ApertureRatio;

//近接ドット
float _ProximityDot;

// Parallax (視差)
float _Parallax;

struct subpixel
{
	float2 pos;
	int num;
};

struct pixel
{
	int2 pos;
	subpixel r, g, b;
};

//画像切替用の変数
sampler2D _LTex;//左眼画像
sampler2D _RTex;//右眼画像
float4 _LTex_ST;
float4 _RTex_ST;

void Swap(inout float a, inout float b)
{
	float t;
	t = a;
	a = b;
	b = t;
}

//画素番号決定関数
int3 PixelNumber(int2 pix)
{
	int3 p;
	if (_ScreenOrientation >= 3)
	{
		pix.x *= 3;
		p.r = ((_PatternNum - _MRatio.y) * pix.x + _MRatio.x * pix.y) % _PatternNum;//画素値の計算導出
		p.g = ((_PatternNum - _MRatio.y) * (pix.x + 1) + _MRatio.x * pix.y) % _PatternNum;
		p.b = ((_PatternNum - _MRatio.y) * (pix.x + 2) + _MRatio.x * pix.y) % _PatternNum;
	}
	else if (_ScreenOrientation < 3)
	{
		pix.y *= 3;
		p.b = ((_PatternNum - _MRatio.y) * pix.x + _MRatio.x * pix.y) % _PatternNum;//画素値の計算導出
		p.g = ((_PatternNum - _MRatio.y) * pix.x + _MRatio.x * (pix.y + 1)) % _PatternNum;
		p.r = ((_PatternNum - _MRatio.y) * pix.x + _MRatio.x * (pix.y + 2)) % _PatternNum;
	}
	p.r += (p.r < 0) ? _PatternNum : 0;
	p.g += (p.g < 0) ? _PatternNum : 0;
	p.b += (p.b < 0) ? _PatternNum : 0;
	if (_ScreenOrientation % 2 == 0) Swap(p.r, p.b);
	return p;
}



pixel InitPixel(int2 pixelPos)
{
	pixel p;
	p.pos = pixelPos + float2(0.5f, 0.5f);
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
	int3 num = PixelNumber(pixelPos);
	p.r.num = num.r;
	p.g.num = num.g;
	p.b.num = num.b;
	return p;
}

float3 CalcEyePosOnOVD(float3 eyePos, float2 subpixelPos)
{
	float t = _OVD / eyePos.z;
	float x = subpixelPos.x;
	float y = subpixelPos.y;
	return float3((1.0f - t) * x + t * eyePos.x, (1.0f - t) * y + t * eyePos.y, _OVD);
}

//中心ドットからサブピクセルに割り振られた番号までの距離
float CalcDotDistance(int subpixelNum, int dot)
{
	float diff = abs(dot + ((_PatternNum % 4 == 0) ? 0.5f : 0) - subpixelNum);
	return (diff <= _PatternNum / 2) ? diff : _PatternNum - diff;
}

float CalcAccurateDotDistance(int subpixelNum, float accurateDot)
{
	float diff = abs(subpixelNum + 0.5f - accurateDot);
	return (diff <= _PatternNum / 2) ? diff : _PatternNum - diff;
}

float CalcAccurateDot(float3 eyePos)
{
	float x = eyePos.x - (eyePos.y / _M) + _Origin;
	float shift_f = abs(x) / _F;
	int shift_i = (int)shift_f;
	float deci = shift_f - shift_i;
	shift_i %= _PatternNum;
	if (x >= 0) return (_PatternNum - 1 - shift_i) % _PatternNum + 0.99999f - deci;
	else return shift_i + deci;
}

float Draw(subpixel sp, float3 clopeanEye, float leftImage, float rightImage);
float Draw(subpixel sp, float3 leftEye, float3 rightEye, float leftImage, float rightImage);
// float Draw(subpixel sp, float3 clopeanEye, float leftImage, float rightImage)
// {
// 	float3 centerOnOVD = CalcEyePosOnOVD(clopeanEye, sp.pos);
// 	float dot = CalcAccurateDot(centerOnOVD);
// 	if(dot < (_PatternNum / 2)) return (sp.num <= (dot + _PatternNum / 2) && (sp.num > dot)) ? leftImage : rightImage;	
// 	else return (sp.num <= dot  && sp.num > (dot - _PatternNum / 2)) ? rightImage : leftImage;
// }

float4 GenerateImage(float3 clopeanEye, float2 uv)
{
	float offset = _Parallax / _DisplayResolution.x;
	float4 leftImage = tex2D(_LTex, uv - float2(offset, 0.0f));
	float4 rightImage = tex2D(_RTex, uv + float2(offset, 0.0f));
	float4 rgba = float4(0, 0, 0, 1);
	pixel p = InitPixel(uv * _DisplayResolution);
	rgba.r = Draw(p.r, clopeanEye, leftImage.r, rightImage.r);
	rgba.g = Draw(p.g, clopeanEye, leftImage.g, rightImage.g);
	rgba.b = Draw(p.b, clopeanEye, leftImage.b, rightImage.b);
	return rgba;
}

float4 GenerateImage(float3 leftEye, float3 rightEye, float2 uv)
{
	float offset = _Parallax / _DisplayResolution.x;
	float4 leftImage = tex2D(_LTex, uv - float2(offset, 0.0f));
	float4 rightImage = tex2D(_RTex, uv + float2(offset, 0.0f));
	float4 rgba = float4(0, 0, 0, 1);
	pixel p = InitPixel(uv * _DisplayResolution);
	rgba.r = Draw(p.r, leftEye, rightEye, leftImage.r, rightImage.r);
	rgba.g = Draw(p.g, leftEye, rightEye, leftImage.g, rightImage.g);
	rgba.b = Draw(p.b, leftEye, rightEye, leftImage.b, rightImage.b);
	return rgba;
}