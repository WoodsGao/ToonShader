using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class PostProcessing : MonoBehaviour
{
    public List<Material> materials = new List<Material>();

    void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
    }

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        var ping = true;
        foreach (var material in materials)
        {
            if(ping)
            {
                Graphics.Blit(src, dest, material);
            }else{
                Graphics.Blit(dest, src, material);
            }
            ping = !ping;
        }
        if (ping)
        {
            Graphics.Blit(src, dest);
        }
    }
}
