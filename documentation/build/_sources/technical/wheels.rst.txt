.. \_wheel\_suspension\_example:

# Wheel Suspension Example (Godot 4)

This document demonstrates a stable and realistic way to simulate aircraft landing gear wheels using GDScript in Godot 4. Instead of using physical wheel constraints, we simulate spring and friction forces using RayCast3D.

## Overview

This approach:

* Uses RayCast3D to detect ground contact
* Applies spring and damping force for suspension
* Adds simple friction to simulate braking and lateral resistance
* Optionally rotates the visual wheel mesh
* Avoids physics instability caused by hinge joints

## GDScript Code

.. code-block:: gdscript

# WheelSuspension.gd
```
    extends Node3D
    class\_name WheelSuspension

    @export var suspension\_length := 0.5  # maximum spring extension (m)
    @export var spring\_strength := 20000.0  # spring constant (N/m)
    @export var damping := 4000.0  # damping force (N/(m/s))
    @export var wheel\_radius := 0.3
    @export var friction := 1.5  # surface friction coefficient
    @export var rotate\_wheel\_visual := true

    @onready var raycast = \$RayCast3D
    @onready var wheel\_mesh = \$WheelMesh  # for optional wheel rotation

    var compression := 0.0
    var previous\_compression := 0.0
    var current\_rotation := 0.0

    func \_physics\_process(delta):
    if not raycast.is\_colliding():
    previous\_compression = compression
    compression = 0.0
    return


   var contact_normal = raycast.get_collision_normal()
   var local_velocity = to_local(get_parent().get_linear_velocity_at_position(global_position))

   # Suspension force
   var distance = raycast.length - raycast.get_collision_distance()
   compression = clamp(distance, 0.0, suspension_length)
   var compression_velocity = (compression - previous_compression) / delta
   previous_compression = compression

   var spring_force = spring_strength * compression
   var damping_force = damping * compression_velocity
   var total_force = (spring_force - damping_force) * contact_normal

   # Lateral friction (simplified)
   var lateral_velocity = local_velocity.x
   var friction_force = -lateral_velocity * friction * contact_normal.length()
   var total_force_global = -contact_normal * total_force + transform.basis.x * friction_force

   # Apply force to parent (aircraft)
   get_parent().apply_central_force(total_force_global)

   # Visual wheel rotation
   if rotate_wheel_visual:
       var forward_speed = -local_velocity.z
       current_rotation += (forward_speed / wheel_radius) * delta
       wheel_mesh.rotation.x = current_rotation
```

## Scene Structure

\::

PlaneBody (RigidBody3D)
└── WheelNode (Node3D)
├── RayCast3D (points downward)
└── WheelMesh (visual model)

## Tips

* Place one WheelSuspension per wheel (main gear, nose gear, etc.)
* Tune spring and damping values to match aircraft mass
* Add steering logic to front gear using rotation inputs
* Detect landings via compression threshold

This method offers stability and simplicity, while being visually and physically convincing for most simulation needs.
