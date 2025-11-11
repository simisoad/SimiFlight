class_name MassComponent extends CSGMesh3D

## Mass of this component
@export var mass: float = 1.0
#@export var aircraft: RigidBody3D
#var gravity_force: Vector3 


func _ready() -> void:
	#if aircraft == null:
		#push_error("MassComponent %, parent aircraft not set!"  % self.name)
		#return
	self.visible = false
	#_gravity()
##f = m*a
#func _gravity() -> void:
	#var pos_offset: Vector3 = aircraft.global_position - self.global_position
	#var gravity_dir: Vector3 = Vector3.DOWN
	#gravity_force = (self.mass * 9.81) * gravity_dir
	#self.aircraft.add_constant_force(gravity_force, pos_offset)
	
#func _process(delta: float) -> void:
	#DebugDraw3D.draw_line(self.global_position, self.global_position + gravity_force)
