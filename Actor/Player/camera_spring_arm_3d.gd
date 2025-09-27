extends SpringArm3D

@export var mouse_sensibility: float = 0.005

@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle: float =  -PI/4
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle: float =  PI/4

func _ready() -> void:
	# 捕獲滑鼠游標
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# 水平旋轉（左右看）
		rotation.y -= event.relative.x * mouse_sensibility
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		
		# 垂直旋轉（上下看）
		rotation.x -= event.relative.y * mouse_sensibility
		rotation.x = clamp(rotation.x, min_vertical_angle, max_vertical_angle)
		
	# 按 ESC 釋放滑鼠
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
