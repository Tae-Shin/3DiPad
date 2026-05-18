//スタートピクセル[px]
int _StartPixel;

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
float _PatternNum;

int _IsSBS;

//ディスプレイの向き
int _ScreenOrientation;

float _BarrierPitch;
float _ApertureRatio;
float _PixelPitch;
float2 _Size;
float _Gap;
float _N;
int _RefractionFlag;
int _MarkerFlag;
int _Reversal;
float _Origin;

// 傾斜誤差
float _Phi;

// 視差画像を構成する水平ピッチ
float _k;

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
		p.r = (_StartPixel + _MRatio.y * pix.x + (_PatternNum - _MRatio.x) * pix.y) % _PatternNum;//画素値の計算導出
		p.g = (_StartPixel + _MRatio.y * (pix.x + 1) + (_PatternNum - _MRatio.x) * pix.y) % _PatternNum;
		p.b = (_StartPixel + _MRatio.y * (pix.x + 2) + (_PatternNum - _MRatio.x) * pix.y) % _PatternNum;
	}
	else if (_ScreenOrientation < 3)
	{
		pix.y *= 3;
		p.b = (_StartPixel + _MRatio.y * pix.x + (_PatternNum - _MRatio.x) * pix.y) % _PatternNum;//画素値の計算導出
		p.g = (_StartPixel + _MRatio.y * pix.x + (_PatternNum - _MRatio.x) * (pix.y + 1)) % _PatternNum;
		p.r = (_StartPixel + _MRatio.y * pix.x + (_PatternNum - _MRatio.x) * (pix.y + 2)) % _PatternNum;
	}
	p.r += (p.r < 0) ? _PatternNum : 0;
	p.g += (p.g < 0) ? _PatternNum : 0;
	p.b += (p.b < 0) ? _PatternNum : 0;
	if (_ScreenOrientation % 2 == 0) Swap(p.r, p.b);
	return p;
}

int _CheckDot(float dot)
{
	dot %= _PatternNum;
	float ret = dot < 0 ? dot + _PatternNum : dot;
	//ret += 0.5;
	//ret %= _PatternNum;
	return (int)ret;
}

int3 CheckDot(float3 dot)
{
	return int3(_CheckDot(dot.r), _CheckDot(dot.g), _CheckDot(dot.b));
}

float _ShiftDot(float s, float2 processingPixelPos, float2 displayPos, float eyeZ, float2 borderDistance)
{
	float2 pp = processingPixelPos + float2(1.0 / 6.0, 1.0 / 2.0);
	float value = displayPos.x + (pp.y - displayPos.y) / _M;
	float diff = pp.x - value;
	float bd = (diff < 0) ? borderDistance.x : borderDistance.y;
	float shift = 0;
	if (abs(diff) > bd)
	{
		shift = 1 + (int)((abs(diff) - bd) / s);
		shift *= (diff < 0) ^ (eyeZ < _OVD) ? 1 : -1;
	}
	return shift;
}

float3 ShiftDot(float s, int2 processingPixelPos, float2 displayPos, float eyeZ, float2 borderDistance)
{
	float3 shift;
	if (s < _DisplayResolution.x)
	{
		if (_ScreenOrientation >= 3)
		{
			shift.r = _ShiftDot(s, processingPixelPos + float2(0.0, 0.0), displayPos, eyeZ, borderDistance);
			shift.g = _ShiftDot(s, processingPixelPos + float2(1.0 / 3.0, 0), displayPos, eyeZ, borderDistance);
			shift.b = _ShiftDot(s, processingPixelPos + float2(2.0 / 3.0, 0), displayPos, eyeZ, borderDistance);
		}
		else if (_ScreenOrientation < 3)
		{
			shift.r = _ShiftDot(s, processingPixelPos + float2(0, 2.0 / 3.0), displayPos, eyeZ, borderDistance);
			shift.g = _ShiftDot(s, processingPixelPos + float2(0, 1.0 / 3.0), displayPos, eyeZ, borderDistance);
			shift.b = _ShiftDot(s, processingPixelPos + float2(0.0, 0.0), displayPos, eyeZ, borderDistance);
		}
		if (_ScreenOrientation % 2 == 0) Swap(shift.r, shift.b);
	}
	else shift.r = shift.g = shift.b = 0;
	return shift;
}

float f(float x, float d, float z)
{
	return _N * x / sqrt(_Gap * _Gap + x * x) - (d - x) / sqrt(z * z + (d - x) * (d - x));
}

float fPrime(float x, float d, float z)
{
	return -(d - x) * (d - x) / ((d - x) * (d - x) + z * z) / sqrt((d - x) * (d - x) + z * z) + 1 / sqrt((d - x) * (d - x) + z * z) + _N / sqrt(_Gap * _Gap + x * x) - _N * x * x / (_Gap * _Gap + x * x) / sqrt(_Gap * _Gap + x * x);
}

float NewtonMethod(float init, float d, float z)
{
	float x = init;
	for (int i = 0; i < 10; i++)
	{
		x -= f(x, d, z) / fPrime(x, d, z);
	}
	return x;
}

float _ShiftRefraction(float2 processingPixelPos, float3 eyePos)
{
	float2 pp = (processingPixelPos + float2(1.0 / 6.0, 1.0 / 2.0) - _DisplayResolution / 2.0) * _PixelPitch;
	float d = sqrt((eyePos.x - pp.x) * (eyePos.x - pp.x) + (eyePos.y - pp.y) * (eyePos.y - pp.y));
	float x = NewtonMethod(0, d, eyePos.z);
	float theta1 = atan((d - x) / eyePos.z);
	float theta2 = asin(sin(theta1) / _N);
	//theta2 = atan(x / _Gap);
	float delta = _Gap * tan(theta1) * (cos(theta1) - cos(theta2)) / cos(theta2);
	float deltaX, deltaY;
	deltaX = delta * (pp.x - eyePos.x) / d;
	deltaY = delta * (pp.y - eyePos.y) / d;
	float threshX, threshY;
	threshX = _PixelPitch / 3.0;
	threshY = _PixelPitch;
	if (_ScreenOrientation < 3) Swap(threshX, threshY);
	float shift = -_MRatio.y * deltaX / threshX + _MRatio.x * deltaY / threshY;
	shift %= _PatternNum;
	shift += shift < 0 ? _PatternNum : 0;
	return shift;
}

float3 ShiftRefraction(int2 processingPixelPos, float3 eyePos)
{
	float3 shift;
	if (_ScreenOrientation >= 3)
	{
		shift.r = _ShiftRefraction(processingPixelPos + float2(0.0, 0.0), eyePos);
		shift.g = _ShiftRefraction(processingPixelPos + float2(1.0 / 3.0, 0.0), eyePos);
		shift.b = _ShiftRefraction(processingPixelPos + float2(2.0 / 3.0, 0.0), eyePos);
	}
	else if (_ScreenOrientation < 3)
	{
		shift.r = _ShiftRefraction(processingPixelPos + float2(0.0, 2.0 / 3.0), eyePos);
		shift.g = _ShiftRefraction(processingPixelPos + float2(0.0, 1.0 / 3.0), eyePos);
		shift.b = _ShiftRefraction(processingPixelPos + float2(0.0, 0.0), eyePos);
	}
	if (_ScreenOrientation % 2 == 0) Swap(shift.r, shift.b);
	return shift;
}