using UnityEngine;

[CreateAssetMenu(fileName = "3D_Display", menuName = "DisplayConfig")]
public class DisplayConfig : ScriptableObject
{
    // Origin position (experimental value) [mm]
    [SerializeField] private Vector2 _origin;
    // OVD [mm]
    [SerializeField] private float _ovd;
    // Designed pupillary distance (PD) [mm]
    [SerializeField] private float _designE;
    // PD in experiment [mm]
    [SerializeField] private float _experimentalE;
    [SerializeField] private bool _fixedResolution = true;
    // Display Resolution (horizontal [px] x vertical [px]) 
    [SerializeField] private Vector2 _resolution;
    // Pixel pitch [mm]
    [SerializeField] private float _pixelPitch;
    // Barrier slanted angle (X : Y) [subpx]
    [SerializeField] private Vector2 _acrossSubpixel;
    // Start pixel [px]
    [SerializeField] private int[] _startPixel = new int[4] { 0, 0, 0, 0 };
    // The number of Pattern [px]
    [SerializeField] private int _patternNum;
    [SerializeField] private float _apertureRatio;
    [SerializeField] private int _proximityDot;
    [SerializeField] private bool _fixedOrientation = true;
    [SerializeField] private ScreenOrientation _orientation;
    [SerializeField] private float _refractiveIndex;
    [SerializeField] private float _gap;

    public Vector2 Origin
    {
        get
        {
            if (Orientation == ScreenOrientation.LandscapeLeft) return _origin;
            else if (Orientation == ScreenOrientation.LandscapeRight) return -_origin;
            else if (Orientation == ScreenOrientation.Portrait) return new Vector2(_origin.y, -_origin.x);
            else return new Vector2(-_origin.y, -_origin.x);
        }
    }

    public float OVD { get { return _ovd; } }

    public float DesignE { get { return _designE; } }

    public float ExperimentalE { get { return _experimentalE; } }

    public Vector2 Resolution
    {
        get
        {
            if (_fixedResolution)
            {
                if (IsLandscape) return _resolution;
                else if (IsPortrait) return new Vector2(_resolution.y, _resolution.x);
                else return _resolution;
            }
            else return new Vector2(Screen.currentResolution.width, Screen.currentResolution.height);
        }
    }

    public float PixelPitch { get { return _pixelPitch; } }

    public Vector2 Size { get { return Resolution * PixelPitch; } }

    public float DotSpaceWidth { get { return PatternNum > 1 ? 2 * ExperimentalE / PatternNum : 0; } }

    public float Slope
    {
        get
        {
            return IsLandscape ? 3.0f * _acrossSubpixel.y / _acrossSubpixel.x : -_acrossSubpixel.x / 3.0f / _acrossSubpixel.y;
        }
    }

    public Vector2 AcrossSubpixel
    {
        get
        {
            var a = IsLandscape ? _acrossSubpixel.x : Mathf.Abs(_acrossSubpixel.y);
            var b = IsLandscape ? _acrossSubpixel.y : Mathf.Sign(Slope) * _acrossSubpixel.x;
            return new Vector2(a, b);
        }
    }

    public int StartPixel
    {
        get
        {
            if (Orientation == ScreenOrientation.LandscapeLeft) return _startPixel[0];
            else if (Orientation == ScreenOrientation.Portrait) return _startPixel[1];
            else if (Orientation == ScreenOrientation.LandscapeRight) return _startPixel[2];
            else return _startPixel[3];
        }
    }
    public int PatternNum { get { return _patternNum; } }

    public float ApertureRatio { get { return _apertureRatio; } }

    public int ProximityDot { get { return _proximityDot; } }

    public ScreenOrientation Orientation { get { return _fixedOrientation ? _orientation : Screen.orientation; } }

    int GCD(int a, int b)
    {
        return b == 0 ? a : GCD(b, a % b);
    }

    public void SendToShader()
    {
        Shader.SetGlobalInt("_ScreenOrientation", (int)Orientation);
        Shader.SetGlobalFloat("_OVD", OVD);
        Shader.SetGlobalFloat("_F", 2 * ExperimentalE / PatternNum);
        Shader.SetGlobalFloat("_E", DesignE);
        Shader.SetGlobalVector("_DisplayResolution", Resolution);
        Shader.SetGlobalFloat("_M", Slope);
        Shader.SetGlobalVector("_MRatio", AcrossSubpixel);
        Shader.SetGlobalInt("_StartPixel", StartPixel);
        Shader.SetGlobalInt("_PatternNum", PatternNum);
        Shader.SetGlobalFloat("_ApertureRatio", ApertureRatio);
        Shader.SetGlobalInt("_ProximityDot", ProximityDot);
        Shader.SetGlobalFloat("_PixelPitch", PixelPitch);
        Shader.SetGlobalFloat("_N", _refractiveIndex);
        Shader.SetGlobalFloat("_Gap", _gap);
    }

    private bool IsLandscape
    {
        get
        {
            return Orientation == ScreenOrientation.LandscapeLeft || Orientation == ScreenOrientation.LandscapeRight;
        }
    }

    private bool IsPortrait
    {
        get
        {
            return Orientation == ScreenOrientation.Portrait || Orientation == ScreenOrientation.PortraitUpsideDown;
        }
    }
}
