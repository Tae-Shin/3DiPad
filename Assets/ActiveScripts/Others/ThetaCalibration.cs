using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class ThetaCalibration : MonoBehaviour
{
    [Header("UI Setting")]
    [SerializeField] private Slider _rotationSlider;
    [SerializeField] private TMP_InputField _valueText;

    // 設計上の基準値（回転ゼロの状態）
    private Vector2 _baseSubpixelRatio;
    private float _baseE; // 眼間距離の基準値

    void Start()
    {
        if (Initializer.display == null)
        {
            Debug.LogError("DisplayConfig is not initialized.");
            return;
        }

        // 1. 初期値の取得
        Vector2 rawRatio = Initializer.display.AcrossSubpixel; 
        
        // 2. 符号の強制設定 (右下がり固定)
        // Y成分は常にマイナスとして初期化します。
        _baseSubpixelRatio = new Vector2(Mathf.Abs(rawRatio.x), -Mathf.Abs(rawRatio.y));

        _baseE = Initializer.display.ExperimentalE;

        // スライダーの初期化
        if (_rotationSlider != null)
        {
            _rotationSlider.minValue = -9.4632f;
            _rotationSlider.maxValue = 5.0f;
            _rotationSlider.value = 0.0f;
            _rotationSlider.onValueChanged.AddListener(OnRotationChanged);

            if (_valueText != null) _valueText.text = $"{0.0f:F3}°";
        }
    }

    public void OnRotationChanged(float angleDeg)
    {
        // UI表示更新
        if (_valueText != null) _valueText.text = $"{angleDeg:F3}°";

        // ---------------------------------------------------------
        // 1. 物理空間への変換 (Aspect Ratio 1:3 補正)
        // ---------------------------------------------------------
        // プログラム上の a はサブピクセル数、b は行数です。
        // 物理的には 1サブピクセル幅 = 1/3 ピクセル幅 なので、
        // 水平成分を 1/3 に圧縮して「物理的な形状」にします。
        
        float physBaseX = _baseSubpixelRatio.x / 3.0f;
        float physBaseY = _baseSubpixelRatio.y; // Yはそのまま (1行=1単位)

        // ---------------------------------------------------------
        // 2. 回転行列の適用 (物理空間での回転)
        // ---------------------------------------------------------
        float rad = angleDeg * Mathf.Deg2Rad;
        float cos = Mathf.Cos(rad);
        float sin = Mathf.Sin(rad);

        // 物理ベクトルを回転
        float physNewX = physBaseX * cos - physBaseY * sin;
        float physNewY = physBaseX * sin + physBaseY * cos;

        // ---------------------------------------------------------
        // 3. 論理空間への復元 (Shader用)
        // ---------------------------------------------------------
        // 物理空間での X を 3倍して、再び「サブピクセル単位」に戻します
        float newX = physNewX * 3.0f;
        float newY = physNewY;

        Debug.Log($"Angle: {angleDeg:F3}, NewRatio: ({newX}, {newY})");

        Vector2 newRatio = new Vector2(newX, newY);

        // ---------------------------------------------------------
        // 4. シェーダーパラメータの更新
        // ---------------------------------------------------------
        
        Shader.SetGlobalVector("_MRatio", newRatio);

        // _M (Slope) の再計算
        float newSlope = 0;
        if (Mathf.Abs(newRatio.x) > 0.0001f)
        {
            bool isLandscape = (Screen.orientation == ScreenOrientation.LandscapeLeft || Screen.orientation == ScreenOrientation.LandscapeRight);
            
            if(isLandscape)
            {
                // 横置き: 3 * y / x
                newSlope = 3.0f * newRatio.y / newRatio.x;
            }
            else
            {
                // 縦置き: -x / (3 * y)
                newSlope = -newRatio.x / (3.0f * newRatio.y);
            }
        }
        Shader.SetGlobalFloat("_M", newSlope);

        // 視域幅の補正
        // ここでの physicalCos は回転によるピッチの変化率なのでそのままでOK
        float physicalCos = Mathf.Cos(rad);
        if (Mathf.Abs(physicalCos) < 0.001f) physicalCos = 1.0f;

        float scaleFactor = 1.0f / physicalCos;
        float newE = _baseE * scaleFactor;
        
        Shader.SetGlobalFloat("_E", newE);
        
        float newF = 2.0f * newE / Initializer.display.PatternNum;
        Shader.SetGlobalFloat("_F", newF);
    }
}