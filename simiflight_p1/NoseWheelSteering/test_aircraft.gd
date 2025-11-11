@tool
class_name TestAircraft extends RigidBody3D
var is_active: bool = true
var force_val: float = -2068.0
var force_dir: Vector3 = Vector3.FORWARD
var steer_dir: float
var steer_speed: float = 1.0
var thrust_pos_offset: Vector3
var axis_locked: bool = false
var center_of_mass_glob: Vector3
@onready var steering_wheel = %NoseGear
@onready var com: Label = %CoM_Label
@onready var wait: float = 0.0
@onready var brake_component: BrakeComponent = %BrakeComponent

@onready var front_wheel_col: CollisionShape3D = %FrontWheel_Col

@export var recalculate_com_editor: bool = false


func _ready() -> void:
	self.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	recalculate_center_of_mass()
	pass

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		wait += delta
		if wait >= 1.0:
			com.text = str("CoM: ", PhysicsServer3D.body_get_direct_state(self.get_rid()).center_of_mass_local)
			com.text += str(", %.2f km/h %.2fm/s" % [(self.linear_velocity.length()*3.6), self.linear_velocity.length()])
			com.text += str(", Brake: ", brake_component.brake_input)
		if not is_active:
			%Camera3D.current = false
		else:
			%Camera3D.current = true

		#_set_friction()

	elif recalculate_com_editor:
		var com_pos = PhysicsServer3D.body_get_direct_state(self.get_rid()).center_of_mass
		%CoM.global_position = com_pos
		recalculate_center_of_mass()



#Idee: Wenn die räder nicht mehr an den Boden kommen, jedoch ein sonstiger Teil des Flugzeuges,
# dann muss die Friction grösser sein,damit das Flugzeug nicht ewigs herumrutscht.
# Idee ist richtig, aber so macht es noch keinen Sinn.
#func _set_friction() -> void:
	#var gears: Array = %Gear.get_children()
	#var in_air: int = 0
	#for gear in gears:
		#var gear_wheel: AdvancedWheel = gear
		#if not gear_wheel.ray_cast_3d.is_colliding():
			#in_air += 1
	#if in_air == gears.size():
		#self.physics_material_override.friction = 1.0
	#else:
		#self.physics_material_override.friction = 0.0





func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	#self.center_of_mass = state.center_of_mass_local
	pass

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and is_active:
		self.thrust_pos_offset = %CoM.global_position - %ThrustPos.global_position
		force_dir = self.transform.basis.z
		var force: Vector3 = force_dir * force_val
		if Input.is_action_pressed('ui_up'):
			self.apply_force(force, thrust_pos_offset)
			DebugDraw3D.draw_line(%ThrustPos.global_position, %ThrustPos.global_position + force, Color.AQUAMARINE)
		if Input.is_action_pressed('ui_down'):
			self.apply_force(force*-1, thrust_pos_offset)
			DebugDraw3D.draw_line(%ThrustPos.global_position, %ThrustPos.global_position + force*-1, Color.AQUAMARINE)
		if Input.is_action_pressed("ui_left"):
			steer_dir += delta * steer_speed
		if Input.is_action_pressed("ui_right"):
			steer_dir -= delta * steer_speed

		if Input.is_action_just_pressed('ui_accept'):
			steer_dir= 0.0
		steer_dir = clamp(steer_dir, -1.0, 1.0)

		if Input.is_action_pressed("scale_up_collision"):
			front_wheel_col.position.y += delta
		if Input.is_action_pressed("scale_down_collision"):
			front_wheel_col.position.y -= delta
		if Input.is_action_pressed('Brake_add'):
			brake_component.brake_input += delta
			brake_component.brake_input = clamp(brake_component.brake_input, 0, 1.0)
		if Input.is_action_pressed('brake_release'):
			brake_component.brake_input -= delta
			brake_component.brake_input = clamp(brake_component.brake_input, 0, 1.0)
		#print(steer_dir)
		steering_wheel.set_steering_input(steer_dir)

		if Input.is_action_just_pressed("aircraft_axis_lock_toggle"):
			if axis_locked:
				axis_locked = false
				self.axis_lock_angular_x = false
				self.axis_lock_angular_y = false
				self.axis_lock_angular_z = false
				self.axis_lock_linear_x = false
				self.axis_lock_linear_y = false
				self.axis_lock_linear_z = false
			else:
				axis_locked = true
				self.axis_lock_angular_x = true
				self.axis_lock_angular_y = true
				self.axis_lock_angular_z = true
				self.axis_lock_linear_x = true
				self.axis_lock_linear_y = true
				self.axis_lock_linear_z = true
		if Input.is_action_pressed('aircrafte_rotate_x'):
			self.global_rotation.x += delta

		if Input.is_action_pressed('aircrafte_rotate_y'):
			self.global_rotation.y += delta

		if Input.is_action_pressed('aircrafte_rotate_z'):
			self.global_rotation.z += delta


		if Input.is_action_pressed("aircraft_move_up"):
			self.global_position.y += delta * 10
		if Input.is_action_pressed("aircraft_move_down"):
			self.global_position.y -= delta * 10



func recalculate_center_of_mass():
	var weighted_position_sum: Vector3 = Vector3.ZERO
	var total_mass: float = 0.0

	# Finde alle Knoten in der Gruppe "mass_components"
	var components = %MassComponents.get_children()
	if components.size() == 0:
		print("error!")

	for component in components:
		# Wichtig: Sicherstellen, dass die Komponente auch wirklich eine Massen-Komponente ist
		if component is MassComponent:
			# Die Position der Komponente relativ zum RigidBody
			var local_pos = component.transform.origin

			# Addiere zum gewichteten Mittelwert und zur Gesamtmasse
			weighted_position_sum += local_pos * component.mass
			total_mass += component.mass

	# Vermeide eine Division durch Null, falls keine Massen definiert sind
	if total_mass > 0:
		# Die CoM-Formel anwenden
		var new_com = weighted_position_sum / total_mass

		# Den berechneten CoM und die Gesamtmasse auf den RigidBody anwenden
		self.center_of_mass = new_com
		self.mass = total_mass

		print("New Center of Mass: ", self.center_of_mass)
		print("New Total Mass: ", self.mass, " kg")
