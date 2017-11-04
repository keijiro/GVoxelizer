// Kino/Streak - Anamorphic lens flare effect for Unity
// https://github.com/keijiro/KinoStreak

using UnityEngine;
using System.Collections.Generic;

namespace Kino
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    [AddComponentMenu("Kino Image Effects/Streak")]
    public class Streak : MonoBehaviour
    {
        #region Editable variables and public properties

        [SerializeField, Range(0, 5)]
        float _threshold = 1;

        public float threshold {
            get { return _threshold; }
            set { _threshold = value; }
        }

        [SerializeField, Range(0, 1)]
        float _stretch = 0.75f;

        public float stretch {
            get { return _stretch; }
            set { _stretch = value; }
        }

        [SerializeField, Range(0, 1)]
        float _intensity = 0.3f;

        public float intensity {
            get { return _intensity; }
            set { _intensity = value; }
        }

        [SerializeField, ColorUsage(false)]
        Color _tint = new Color(0.55f, 0.55f, 1);

        public Color tint {
            get { return _tint; }
            set { _tint = value; }
        }

        #endregion

        #region Private variables and functions

        [SerializeField, HideInInspector] Shader _shader;
        Material _material;

        // This stack is reused between frames to avoid GC memory allocation.
        Stack<RenderTexture> _mipStack = new Stack<RenderTexture>();

        RenderTexture GetTempRT(int width, int height)
        {
            var format = RenderTextureFormat.ARGBHalf;
            var rt = RenderTexture.GetTemporary(width, height, 0, format);
            return rt;
        }

        #endregion

        #region MonoBehaviour functions

        void OnDestroy()
        {
            if (_material != null)
            {
                if (Application.isPlaying)
                    Destroy(_material);
                else
                    DestroyImmediate(_material);
            }
        }

        void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            if (_material == null)
            {
                _material = new Material(_shader);
                _material.hideFlags = HideFlags.DontSave;
            }

            // Common parameters.
            _material.SetFloat("_Threshold", _threshold);
            _material.SetFloat("_Stretch", _stretch);
            _material.SetFloat("_Intensity", _intensity);
            _material.SetColor("_Color", _tint);

            // Apply the prefilter and make it half height.
            var width = source.width;
            var height = source.height / 2;
            var prefiltered = GetTempRT(width, height);
            Graphics.Blit(source, prefiltered, _material, 0);

            // Build a MIP pyramid.
            var last = prefiltered;

            while (width > 16) // minimum width = 8
            {
                width /= 2;
                var down = GetTempRT(width, height);
                Graphics.Blit(last, down, _material, 1);
                _mipStack.Push(last = down);
            }

            // The last element of the stack is in (last), so cut it.
            _mipStack.Pop();

            // Upsample and combine.
            while (_mipStack.Count > 0)
            {
                var hi = _mipStack.Pop();
                var up = GetTempRT(hi.width, hi.height);
                _material.SetTexture("_HighTex", hi);
                Graphics.Blit(last, up, _material, 2);
                RenderTexture.ReleaseTemporary(last);
                RenderTexture.ReleaseTemporary(hi);
                last = up;
            }

            // Final composition.
            _material.SetTexture("_HighTex", source);
            Graphics.Blit(last, destination, _material, 3);

            // Cleaning up.
            RenderTexture.ReleaseTemporary(last);
            RenderTexture.ReleaseTemporary(prefiltered);
        }

        #endregion
    }
}
