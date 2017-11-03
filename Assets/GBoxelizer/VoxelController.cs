using UnityEngine;
using UnityEngine.Timeline;

[ExecuteInEditMode]
class VoxelController : MonoBehaviour
{
    [SerializeField] float _progress;

    MaterialPropertyBlock _sheet;

    public void Update()
    {
        if (_sheet == null) _sheet = new MaterialPropertyBlock();

        _sheet.SetFloat("_Progress", _progress);

        GetComponent<Renderer>().SetPropertyBlock(_sheet);
    }
}
