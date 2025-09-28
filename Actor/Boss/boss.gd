extends CharacterBody3D

# Boss 屬性
@export var boss_name: String = "成都超人"
@export var max_health: float = 1500.0
@export var move_speed: float = 8.0
@export var jump_height: float = 35.0  # 跳躍高度
@export var attack_interval: float = 5.0  # 攻擊間隔時間
@export var stun_duration: float = 3.0  # 僵直時間
@export var damage_range: float = 3.0  # 傷害範圍

# 第二形態設定
@export var phase2_health_threshold: float = 0.5  # 50%血量觸發第二形態
@export var flying_height: float = 15.0  # 飛行高度
@export var bullet_damage: float = 5.0  # 子彈傷害
@export var shoot_interval: float = 2.0  # 射擊間隔
@export var bullet_speed: float = 20.0  # 子彈速度

var current_health: float
var player: Node = null

# 形態控制
var current_phase: int = 1  # 1=地面形態, 2=飛行形態
var phase2_triggered: bool = false

# 开场控制
var intro_finished: bool = false

# 傷害指示器（外部節點引用）
var damage_indicator: MeshInstance3D

# 場地中央位置
var center_position: Vector3
var is_returning_to_center: bool = false

# 天降攻擊相關變數
var is_sky_attacking: bool = false
var sky_attack_state: String = "none"  # "jumping", "waiting", "falling"
var sky_attack_timer: float = 0.0
var attack_cycle_timer: float = 0.0  # 攻擊循環計時器
var target_fall_position: Vector3

# 暈眩狀態變數
var is_stunned: bool = false
var stun_timer: float = 0.0

# 第二形態變數
var shoot_timer: float = 0.0
var flying_target_position: Vector3
var flying_move_timer: float = 0.0

# 音效播放器
var audio_player_bai: AudioStreamPlayer
var audio_player_fight_start: AudioStreamPlayer

var is_active: bool = false   # 預設不啟動
func _on_introarea_intro_finished() -> void:
	is_active = true # Replace with function body.

@onready var health_bar = $BossUI/Panel/VBoxContainer/BossHealthBar
@onready var name_label = $BossUI/Panel/VBoxContainer/BossName

func _ready() -> void:
	current_health = max_health
	name_label.text = boss_name
	health_bar.update_health(current_health, max_health)
	add_to_group("boss")

	# 設定場地中央位置為boss的初始位置
	center_position = global_position

	# 設定碰撞層（用於被玩家攻擊檢測）
	collision_layer = 4  # Boss在層4
	collision_mask = 1 | 2  # 可以碰撞地面(層1)和玩家(層2)

	# 延遲尋找玩家，確保玩家已經初始化
	call_deferred("find_player")
	call_deferred("connect_to_player_signals")

	# 獲取外部傷害指示器節點
	damage_indicator = get_tree().get_first_node_in_group("damage_indicator")

	# 初始化音效播放器
	setup_audio_players()

# 尋找玩家函數
func find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not player:
		# 如果還是找不到，1秒後再試一次
		get_tree().create_timer(1.0).timeout.connect(find_player)

func _physics_process(delta: float) -> void:
	if current_health <= 0 or not player:
		return

	# 如果开场还没结束，不进行任何攻击行为
	if not intro_finished:
		return

	# 檢查是否需要切換到第二形態
	check_phase_transition()
	
	
	if current_phase == 1:
		# 第一形態：地面攻擊
		handle_phase1(delta)
	else:
		# 第二形態：飛行射擊
		handle_phase2(delta)

	move_and_slide()

# 處理第一形態
func handle_phase1(delta: float) -> void:
	# 更新攻擊循環計時器
	attack_cycle_timer += delta

	# 處理暈眩狀態
	if is_stunned:
		stun_timer += delta
		velocity.x = 0
		velocity.z = 0

		if stun_timer >= stun_duration:
			end_stun()
	# 處理天降攻擊
	elif is_sky_attacking:
		handle_sky_attack(delta)
	# 處理回到中央
	elif is_returning_to_center:
		return_to_center(delta)
	else:
		# 檢查是否到了攻擊時間（每5秒攻擊一次）
		if attack_cycle_timer >= attack_interval:
			start_sky_attack()
		else:
			# 在中央待機
			velocity.x = 0
			velocity.z = 0

	# 應用重力（除非在攻擊狀態）
	if not is_on_floor() and not is_sky_attacking:
		velocity.y -= 75 * delta

# 處理第二形態
func handle_phase2(delta: float) -> void:
	# 更新射擊計時器
	shoot_timer += delta
	flying_move_timer += delta

	# 飛行行為：繞著玩家飛行
	flying_behavior(delta)

	# 射擊行為
	if shoot_timer >= shoot_interval:
		shoot_at_player()
		shoot_timer = 0.0

	# 維持飛行高度
	velocity.y = 0  # 停止垂直移動
	global_position.y = flying_height


# 受傷函數
func take_damage(amount: float) -> void:
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	health_bar.update_health(current_health, max_health)
	
	
	if current_health <= 0:
		die()

func die() -> void:
	print(boss_name + " 被擊敗了！")
	$BossUI.visible = false
	# 播放死亡動畫
	# queue_free()  # 移除 Boss

# 開始天降攻擊
func start_sky_attack() -> void:
	if is_sky_attacking:
		return

	if not player:
		return

	is_sky_attacking = true
	sky_attack_state = "jumping"
	sky_attack_timer = 0.0
	attack_cycle_timer = 0.0  # 重置攻擊循環計時器

	# 鎖定玩家當前位置作為落地目標
	target_fall_position = player.global_position
	print("鎖定目標位置：", target_fall_position)

	# 顯示傷害指示器
	show_damage_indicator(target_fall_position)

	# 開始跳躍
	velocity.y = jump_height
	velocity.x = 0
	velocity.z = 0

# 處理天降攻擊的各個階段
func handle_sky_attack(delta: float) -> void:
	sky_attack_timer += delta

	match sky_attack_state:
		"jumping":
			# 跳躍階段：只在Y軸移動，到達最高點後進入等待
			# 應用重力減緩跳躍
			velocity.y -= 75 * delta

			if velocity.y <= 0:  # 開始下降時切換到等待狀態
				sky_attack_state = "waiting"
				sky_attack_timer = 0.0
				velocity.y = 0  # 懸停在空中

		"waiting":
			# 等待階段：懸停1秒
			velocity.x = 0
			velocity.z = 0
			velocity.y = 0  # 保持懸停

			if sky_attack_timer >= 1.0:  # 1秒後開始下降
				sky_attack_state = "falling"
				sky_attack_timer = 0.0
				# 播放falling音效
				if audio_player_bai:
					audio_player_bai.play()

		"falling":
			# 下降階段：直接移動到目標位置
			# 強制設定到目標的X和Z座標
			global_position.x = target_fall_position.x
			global_position.z = target_fall_position.z
			curAnim = LENDING

			# 快速下降
			velocity.x = 0
			velocity.z = 0
			velocity.y = -jump_height * 1.5  # 下降速度比跳躍更快

			# 檢查是否著陸
			if is_on_floor():
				print("Boss落地位置：", global_position)
				print("目標位置：", target_fall_position)
				print("距離差：", global_position.distance_to(target_fall_position))
				end_sky_attack()

# 結束天降攻擊
func end_sky_attack() -> void:
	is_sky_attacking = false
	sky_attack_state = "none"
	sky_attack_timer = 0.0

	# 隱藏傷害指示器
	hide_damage_indicator()

	# 落地時對附近玩家造成傷害
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= damage_range:  # 使用設定的傷害範圍
		# 對玩家造成10點傷害
		if player.has_method("take_damage"):
			player.take_damage(10.0)
			print("Boss天降攻擊擊中玩家！造成10點傷害")
		else:
			print("Boss天降攻擊擊中玩家，但玩家沒有take_damage方法")

	# 開始暈眩狀態
	start_stun()

# 開始暈眩狀態
func start_stun() -> void:
	is_stunned = true
	stun_timer = 0.0
	velocity.x = 0
	velocity.z = 0

# 結束暈眩狀態
func end_stun() -> void:
	is_stunned = false
	stun_timer = 0.0

	# 開始回到中央
	is_returning_to_center = true

# 回到場地中央
func return_to_center(delta: float) -> void:
	var distance_to_center = global_position.distance_to(center_position)

	# 如果已經接近中央位置，停止移動
	if distance_to_center <= 1.0:
		is_returning_to_center = false
		velocity.x = 0
		velocity.z = 0
		global_position.x = center_position.x
		global_position.z = center_position.z
	else:
		# 移動到中央位置
		var direction_to_center = (center_position - global_position).normalized()
		direction_to_center.y = 0  # 只在水平面移動

		velocity.x = direction_to_center.x * move_speed
		velocity.z = direction_to_center.z * move_speed


# 顯示傷害指示器
func show_damage_indicator(position: Vector3) -> void:
	if damage_indicator:
		# 設定指示器位置，強制Y座標為地面高度
		var ground_position = Vector3(position.x, 0.1, position.z)  # 稍微提高一點避免Z-fighting
		damage_indicator.global_position = ground_position
		damage_indicator.visible = true

		# 重置閃爍效果
		if damage_indicator.has_method("reset_flash"):
			damage_indicator.reset_flash()

		print("目標位置：", position)
		print("地面位置：", ground_position)
		print("傷害指示器實際位置：", damage_indicator.global_position)
		print("傷害指示器可見性：", damage_indicator.visible)

# 隱藏傷害指示器
func hide_damage_indicator() -> void:
	if damage_indicator:
		damage_indicator.visible = false

# 檢查形態轉換
func check_phase_transition() -> void:
	var health_percentage = current_health / max_health
	if health_percentage <= phase2_health_threshold and not phase2_triggered:
		trigger_phase2()

# 觸發第二形態
func trigger_phase2() -> void:
	current_phase = 2
	phase2_triggered = true

	# 停止所有第一形態的行為
	is_sky_attacking = false
	is_stunned = false
	is_returning_to_center = false

	# 隱藏傷害指示器
	hide_damage_indicator()

	# 移動到飛行高度
	global_position.y = flying_height

	# 初始化第二形態
	shoot_timer = 0.0
	flying_move_timer = 0.0
	flying_target_position = player.global_position

	print(boss_name + " 進入第二形態：超人型態！")

# 飛行行為
func flying_behavior(delta: float) -> void:
	# 每3秒換一個飛行目標點
	if flying_move_timer >= 3.0:
		flying_move_timer = 0.0
		# 在玩家周圍選擇一個新的飛行點
		var angle = randf() * TAU
		var radius = 10.0
		flying_target_position = player.global_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		flying_target_position.y = flying_height

	# 移動到目標點
	var direction_to_target = (flying_target_position - global_position).normalized()
	direction_to_target.y = 0  # 只在水平面移動

	velocity.x = direction_to_target.x * move_speed * 0.8
	velocity.z = direction_to_target.z * move_speed * 0.8

# 向玩家射擊
func shoot_at_player() -> void:
	if not player:
		return

	# 計算射擊方向
	var direction_to_player = (player.global_position - global_position).normalized()

	# 創建子彈
	var bullet_scene = preload("res://Actor/Boss/Bullet.tscn")
	var bullet = bullet_scene.instantiate()

	# 將子彈添加到場景
	get_tree().current_scene.add_child(bullet)

	# 設定子彈屬性
	bullet.setup(global_position, direction_to_player, bullet_damage, bullet_speed)

	print("Boss發射子彈！")






#動襪

enum {IDLE, LENDING}
var curAnim = LENDING

@onready var Boss_anim_tree: AnimationTree = $Pivot/Boss/boss_V2/AnimationTree

@onready var blend_speed = 15


var lending_val = 1

func handle_animation(delta):
	match curAnim:
		IDLE:
			lending_val = lerpf(lending_val, 0, blend_speed * delta)
		LENDING:
			lending_val = lerpf(lending_val, 1, blend_speed * delta)
			
func update_tree ():
	Boss_anim_tree["parameters/Lending/blend_amount"] = lending_val

# 設置音效播放器
func setup_audio_players():
	# 創建bai音效播放器
	audio_player_bai = AudioStreamPlayer.new()
	var bai_audio = load("res://Audio/bai.mp3")
	audio_player_bai.stream = bai_audio
	add_child(audio_player_bai)

	# 創建fight_start音效播放器
	audio_player_fight_start = AudioStreamPlayer.new()
	var fight_start_audio = load("res://Audio/fight_start.mp3")
	audio_player_fight_start.stream = fight_start_audio
	add_child(audio_player_fight_start)

# 连接player的信号
func connect_to_player_signals():
	if player and player.has_signal("intro_finished"):
		player.intro_finished.connect(_on_intro_finished)

# 开场结束回调
func _on_intro_finished():
	intro_finished = true
	print("Boss收到开场结束信号，开始攻击！")
