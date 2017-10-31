using UnityEngine;

[ExecuteInEditMode]
public class Contour : MonoBehaviour
{
    [SerializeField, ColorUsage(false)] Color _background = Color.black;
    [SerializeField, ColorUsage(false)] Color _foreground = Color.white;
    [SerializeField, Range(0, 1)] float _lowerThreshold = 0.1f;
    [SerializeField, Range(0, 1)] float _upperThreshold = 0.2f;
    [SerializeField, HideInInspector] Shader _shader;

    Material _material;

    void OnValidate()
    {
        _upperThreshold = Mathf.Max(_lowerThreshold, _upperThreshold);
    }

    void OnDestroy()
    {
        if (_material != null)
            if (Application.isPlaying)
                Destroy(_material);
            else
                DestroyImmediate(_material);
    }

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture dest)
    {
        if (_material == null)
        {
            _material = new Material(_shader);
            _material.hideFlags = HideFlags.DontSave;
        }

        _material.SetColor("_Color0", _background);
        _material.SetColor("_Color1", _foreground);
        _material.SetFloat("_Threshold1", _lowerThreshold);
        _material.SetFloat("_Threshold2", _upperThreshold);

        Graphics.Blit(source, dest, _material, 0);
    }
}
