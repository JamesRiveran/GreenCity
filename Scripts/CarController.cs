using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;


/// Controlador del vehículo que maneja el movimiento, la dirección y el frenado.
/// Soporta múltiples jugadores mediante configuración de teclas personalizadas.

public class CarController : MonoBehaviour
{
    // Variables para almacenar las entradas del jugador
    private float horizontalInput;      // Entrada para la dirección (izquierda/derecha)
    private float verticalInput;        // Entrada para la aceleración (adelante/atrás)
    private float currentSteerAngle;    // Ángulo de dirección actual
    private float currentbreakForce;    // Fuerza de frenado actual
    private bool isBreaking;            // Estado del freno (presionado o no)

    // Parámetros configurables del vehículo
    [SerializeField] private float motorForce;      // Fuerza del motor
    [SerializeField] private float breakForce;      // Fuerza de frenado
    [SerializeField] private float maxSteerAngle;   // Ángulo máximo de dirección

    // Configuración de teclas para controles personalizados
    [Header("Configuración de Controles")]
    [Tooltip("Tecla para acelerar")]
    [SerializeField] private KeyCode accelerateKey = KeyCode.W;
    
    [Tooltip("Tecla para retroceder")]
    [SerializeField] private KeyCode reverseKey = KeyCode.S;
    
    [Tooltip("Tecla para girar a la izquierda")]
    [SerializeField] private KeyCode leftKey = KeyCode.A;
    
    [Tooltip("Tecla para girar a la derecha")]
    [SerializeField] private KeyCode rightKey = KeyCode.D;
    
    [Tooltip("Tecla para frenar")]
    [SerializeField] private KeyCode brakeKey = KeyCode.Space;

    // Referencias a los WheelColliders (componentes de física de las ruedas)
    [Header("Referencias de Ruedas")]
    [SerializeField] private WheelCollider frontLeftWheelCollider;
    [SerializeField] private WheelCollider frontRightWheelCollider;
    [SerializeField] private WheelCollider rearLeftWheelCollider;
    [SerializeField] private WheelCollider rearRightWheelCollider;

    // Referencias a los Transforms de las mallas visuales de las ruedas
    [SerializeField] private Transform frontLeftWheelTransform;
    [SerializeField] private Transform frontRightWheeTransform;
    [SerializeField] private Transform rearLeftWheelTransform;
    [SerializeField] private Transform rearRightWheelTransform;


    /// Se ejecuta en cada frame de física. Maneja todas las actualizaciones del vehículo.

    private void FixedUpdate()
    {
        GetInput();         // Obtener entrada del jugador
        HandleMotor();      // Manejar motor y frenos
        HandleSteering();   // Manejar dirección
        UpdateWheels();     // Actualizar posición visual de las ruedas
    }


    /// Obtiene la entrada del jugador desde el teclado usando las teclas configuradas.

    private void GetInput()
    {
        // Calcular entrada vertical basada en las teclas de acelerar y retroceder
        verticalInput = 0f;
        if (Input.GetKey(accelerateKey))
            verticalInput = 1f;
        else if (Input.GetKey(reverseKey))
            verticalInput = -1f;
        
        // Calcular entrada horizontal basada en las teclas de izquierda y derecha
        horizontalInput = 0f;
        if (Input.GetKey(leftKey))
            horizontalInput = -1f;
        else if (Input.GetKey(rightKey))
            horizontalInput = 1f;
        
        // Verificar si se está presionando la tecla de freno
        isBreaking = Input.GetKey(brakeKey);
    }


    /// Maneja la aceleración y el frenado del vehículo.

    private void HandleMotor()
    {
        // Aplicar torque del motor a las ruedas delanteras
        frontLeftWheelCollider.motorTorque = verticalInput * motorForce;
        frontRightWheelCollider.motorTorque = verticalInput * motorForce;
        
        // Calcular la fuerza de frenado (si está frenando usar breakForce, si no 0)
        currentbreakForce = isBreaking ? breakForce : 0f;
        
        // Aplicar el frenado a todas las ruedas
        ApplyBreaking();       
    }


    /// Aplica la fuerza de frenado a todas las ruedas.

    private void ApplyBreaking()
    {
        frontRightWheelCollider.brakeTorque = currentbreakForce;
        frontLeftWheelCollider.brakeTorque = currentbreakForce;
        rearLeftWheelCollider.brakeTorque = currentbreakForce;
        rearRightWheelCollider.brakeTorque = currentbreakForce;
    }


    /// Maneja la dirección del vehículo basada en la entrada horizontal.

    private void HandleSteering()
    {
        // Calcular el ángulo de dirección basado en la entrada
        currentSteerAngle = maxSteerAngle * horizontalInput;
        
        // Aplicar el ángulo de dirección solo a las ruedas delanteras
        frontLeftWheelCollider.steerAngle = currentSteerAngle;
        frontRightWheelCollider.steerAngle = currentSteerAngle;
    }


    /// Actualiza la posición y rotación visual de todas las ruedas.

    private void UpdateWheels()
    {
        UpdateSingleWheel(frontLeftWheelCollider, frontLeftWheelTransform);
        UpdateSingleWheel(frontRightWheelCollider, frontRightWheeTransform);
        UpdateSingleWheel(rearRightWheelCollider, rearRightWheelTransform);
        UpdateSingleWheel(rearLeftWheelCollider, rearLeftWheelTransform);
    }


    /// Actualiza la posición y rotación de una rueda individual.

    private void UpdateSingleWheel(WheelCollider wheelCollider, Transform wheelTransform)
    {
        Vector3 pos;
        Quaternion rot;
        
        // Obtener la posición y rotación del WheelCollider
        wheelCollider.GetWorldPose(out pos, out rot);

        // Actualizar la rotación y posición del Transform de la rueda
        //wheelTransform.rotation = rot;
        wheelTransform.position = pos;
    }
}