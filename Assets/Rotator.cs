using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Rotator : MonoBehaviour
{
    public float speed=1;
    // Start is called before the first frame update
    void Start()
    {
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetMouseButton(0))
            transform.rotation = Quaternion.AngleAxis(-speed * Input.GetAxis("Mouse X"), Vector3.up) * transform.rotation;
    }
}
