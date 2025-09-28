extends CharacterBody3D

# 移動相關
@export var speed = 14
@export var fall_acceleration = 75
@export var jump_impulse = 20

@export var dash_speed := 30   # 衝刺速度
@export var dash_duration := 0.2  # 衝刺持續時間（秒）
@export var dash_cd := 1.0 # 衝刺CD (秒)

var dash_timer := 0.0
var is_dashing := false
var dashing_CD := 0.0

# 血量相關
@export var max_health: float = 100.0
var current_health: float

@export var air_control_factor := 0.2  # 空中操作影響比例 (0 = 完全不能操作, 1 = 和地面一樣)

var target_velocity = Vector3.ZERO
var boss: Node = null

@onready var health_bar = $Pivot/UI/HealthBar
@onready var camera = $SpringArm3D/Camera3D



func _ready() -> void:
	current_health = max_health
	health_bar.update_health(current_health, max_health)
	add_to_group("player")
	
	# 設定碰撞層
	collision_layer = 2  # 玩家在層2
	collision_mask = 1 | 4  # 可以碰撞地面(層1)和Boss(層4)
	
	# 尋找Boss
	boss = get_tree().get_first_node_in_group("boss")


func _input(event):
	if event.is_action_pressed("dash") and not is_dashing and dashing_CD <= 0.0 and is_on_floor():
		is_dashing = true
		dash_timer = dash_duration
		dashing_CD = dash_cd
		

func _physics_process(delta):
	# 取得輸入方向
	var input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	
	handle_animation(delta)
	update_tree()
	

	
	var direction = Vector3.ZERO
	
		
	# 衝刺判定

	if is_dashing:
		dash_timer -= delta	
		
		if dash_timer <= 0.0:
			is_dashing = false
		else:
			# 沿著角色正前方（通常 -z）
			var forward = -$Pivot.global_transform.basis.z
			forward.y = 0
			forward = forward.normalized()
			
			velocity.x = forward.x * dash_speed
			velocity.z = forward.z * dash_speed
			move_and_slide()
			return;
	elif dashing_CD > 0.0:
		dashing_CD -= delta

	if is_on_floor():
		#在地面上，無重力
		target_velocity.y = 0
		if input_dir.length() > 0: #有輸入移動方向
			input_dir = input_dir.normalized()
			curAnim = RUN #動畫設為跑步
			
			# 檢查相機是否存在
			if camera != null:
				# 取得相機的 basis,計算相機相對方向
				var cam_basis = camera.global_transform.basis
				
				# 取出相機的前、右方向(去掉 y 分量避免角色往上飄)
				var forward = -cam_basis.z
				forward.y = 0
				forward = forward.normalized()
				
				var right = cam_basis.x
				right.y = 0
				right = right.normalized()
				
				# 把輸入轉換到相機方向
				direction = (right * input_dir.x + forward * input_dir.y).normalized()
			else:
				# 如果沒有相機,使用世界座標方向(備用方案)
				direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
				curAnim = RUN			
			# 角色朝向移動方向
			$Pivot.basis = Basis.looking_at(direction)
		else:
			curAnim = IDLE
	# 地面速度
		# ✅ 水平速度只在地面上更新
		target_velocity.x = direction.x * speed
		target_velocity.z = direction.z * speed
	else:
		# ✅ 空中速度 → 原本速度 + (輸入方向 * 減弱比例)
		target_velocity.x = lerp(velocity.x, direction.x * speed, air_control_factor * delta * 5)
		target_velocity.z = lerp(velocity.z, direction.z * speed, air_control_factor * delta * 5)
		# 重力
		target_velocity.y -= fall_acceleration * delta
		curAnim = JUMP # 動畫設為跳躍

	
	
	# 跳躍
	if Input.is_action_just_pressed("jump") and is_on_floor():
		target_velocity.y = jump_impulse
	
	# 測試功能：Q鍵減少玩家血量
	if Input.is_action_just_pressed("test_player_damage"):
		take_damage(10.0)
	
	# 測試功能：E鍵減少Boss血量
	if Input.is_action_just_pressed("test_boss_damage"):
		if boss and boss.has_method("take_damage"):
			boss.take_damage(30.0)
	
	velocity = target_velocity
	move_and_slide()

# 受傷函數
func take_damage(amount: float) -> void:
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	health_bar.update_health(current_health, max_health)
	
	print("玩家受到 %d 點傷害！剩餘血量：%d" % [amount, current_health])
	
	if current_health <= 0:
		die()

signal hit

func die() -> void:
	print("玩家死亡！")
	hit.emit()
	# 可以加入死亡動畫或重新開始遊戲
	get_tree().reload_current_scene()







#動畫

enum {IDLE, RUN, JUMP}
var curAnim = RUN

@onready var anim_tree: AnimationTree = $Pivot/mainCharacter/AnimationTree

@onready var blend_speed = 15

var run_val = 1
var jump_val = 1



	

func handle_animation(delta):
	match curAnim:
		IDLE:
			run_val = lerpf(run_val, 0, blend_speed * delta)
			jump_val = lerpf(jump_val, 0, blend_speed * delta)
		RUN:
			run_val = lerpf(run_val, 1, blend_speed * delta)
			jump_val = lerpf(jump_val, 0, blend_speed * delta)
		JUMP:
			run_val = lerpf(run_val, 0, blend_speed * delta)
			jump_val = lerpf(jump_val, 1, blend_speed * delta)
			



func update_tree ():
	anim_tree["parameters/Run/blend_amount"] = run_val
	anim_tree["parameters/jump/blend_amount"] = jump_val
	print("更新動畫樹 → Run:", run_val, " Jump:", jump_val)
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
