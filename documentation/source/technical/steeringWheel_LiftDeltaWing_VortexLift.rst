.. \_nose\_gear\_and\_lift\_modeling:

# Nose Gear Steering and Aerodynamic Lift Modeling

This document covers two important aspects of flight dynamics simulation for SimiFlight:

1. Nose gear steering using physics-based lateral forces
2. Dynamic lift point modeling for delta wings and flaps

---

## Part 1: Nose Gear Steering

**Goal**: Simulate realistic ground steering by applying lateral friction forces at the nose wheel.

**Key Idea**:
The steering effect should not rotate the aircraft directly, but instead come from the lateral resistance of the ground reacting to the nose wheel's sideways force.

### Physics Principle

* The engine generates pure forward thrust
* The nose wheel turns to the left/right (steering input)
* The lateral velocity at the contact point generates a side force
* This force rotates the aircraft naturally

### GDScript Outline

```gdscript
@export var is_steerable := false
@export var max_steering_angle := 25.0  # degrees
var steering_input := 0.0  # -1 = left, 1 = right

func set_steering_input(value: float):
    steering_input = clamp(value, -1.0, 1.0)

func _physics_process(delta):
    if not raycast.is_colliding():
        return

    var steer_angle_rad = deg_to_rad(steering_input * max_steering_angle)
    var forward_dir = -transform.basis.z
    var steer_dir = forward_dir.rotated(Vector3.UP, steer_angle_rad)

    var local_velocity = to_local(get_parent().get_linear_velocity_at_position(global_position))

    var lateral_dir = steer_dir.cross(Vector3.UP).normalized()
    var lateral_speed = local_velocity.dot(lateral_dir)

    var side_force = -lateral_speed * friction
    var total_force = lateral_dir * side_force

    get_parent().apply_central_force(total_force)
```

### Notes

* Use local velocity at the wheel point to determine real effect
* Add forward spring force as described in `WheelSuspension`
* Visual rotation of wheel mesh can reflect steering angle

---

## Part 2: Dynamic Lift Point for Delta Wings

**Goal**: Model realistic lift behavior for delta wings and other advanced geometries.

**Problem**: With delta wings, the aerodynamic center (lift point) shifts depending on angle of attack (Alpha), which affects pitch stability.

### Strategy: Dynamic Center of Pressure

Calculate the center of lift based on a formula or curve that shifts with Alpha:

```gdscript
func get_cop_offset(alpha_deg: float) -> float:
    return clamp(0.25 + 0.0015 * alpha_deg, 0.25, 0.7)

func get_lift_point(alpha_deg: float) -> Vector3:
    var offset_ratio = get_cop_offset(alpha_deg)
    var local_point = Vector3(-chord_length * offset_ratio, 0, 0)
    return global_transform.origin + global_transform.basis.xform(local_point)
```

### Result

* More realistic pitch behavior for delta wings
* Smooth stall behavior with less sudden drop

---

## Part 3: Vortex Lift Approximation

Delta wings generate additional lift through vortex effects at high Alpha. This can be simulated without CFD.

### Simplified Vortex Model:

```gdscript
func compute_lift(alpha_deg: float) -> float:
    var alpha_rad = deg_to_rad(alpha_deg)
    var cl_linear = alpha_deg * 0.1
    var cl_vortex = 2.5 * pow(sin(alpha_rad), 2)
    return cl_linear + cl_vortex
```

### Alternative: Curve-Based Lift Model

Use a custom `Curve` to describe:

* Linear region
* Vortex-enhanced lift bump
* Soft stall zone

### Advantages

* Stable behavior for Mirage, Su-27, Gripen, etc.
* Empirically tunable without fluid simulation
* Extendable for flaps, canards, or swept wings

---

Planned Improvements:

* Modular wing system (`WingSection` class)
* Visual vortex debug lines/particles
* Stall and AoA limits per section

This structure makes the aerodynamic simulation extensible and prepares the system for future support of helicopters and unconventional aircraft designs.
