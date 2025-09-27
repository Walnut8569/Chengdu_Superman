extends CharacterBody3D

# How fast the player moves in meters per second.
@export var speed = 14

# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75

# Vertical impulse applied to the character upon jumping in meters per second.
@export var jump_impulse = 20

# Vertical impulse applied to the character upon bouncing over a mob in
# meters per second.
@export var bounce_impulse = 16

var target_velocity = Vector3.ZERO

func _physics_process(delta):
		
		# 取得輸入
	var input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()

		# 將2D輸入轉成3D，先當作 x,z
		#var move_dir = Vector3(input_dir.x, 0, input_dir.y)

		# 取得相機的 basis
		var cam = $SpringArmPivot/SpringArm3D/Camera3D  # 或是存好你的 camera 節點路徑
		var cam_basis = cam.global_transform.basis

		# 取出相機的前、右方向（但要去掉 y，避免角色往上飄）
		var forward = -cam_basis.z
		forward.y = 0
		forward = forward.normalized()

		var right = cam_basis.x
		right.y = 0
		right = right.normalized()

		# 把輸入轉到鏡頭方向
		var final_dir = (right * input_dir.x + forward * input_dir.y).normalized()

		# 用這個 final_dir 來移動
		velocity.x = final_dir.x * speed
		velocity.z = final_dir.z * speed
	else:
		velocity.x = 0
		velocity.z = 0

	# Vertical Velocity
	#if not is_on_floor(): # If in the air, fall towards the floor. Literally gravity
		#velocity.y = velocity.y - (fall_acceleration * delta)
	#elif is_on_floor() and Input.is_action_just_pressed("jump"):
		#velocity.y = jump_impulse
		

	# Moving the Character
	#velocity = target_velocity
	move_and_slide()
	
signal hit

func die():
	hit.emit()
	queue_free()
