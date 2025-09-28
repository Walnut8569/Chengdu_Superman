extends CharacterBody3D

# Boss 屬性
@export var boss_name: String = "成都超人"
@export var max_health: float = 1500.0
@export var move_speed: float = 8.0
@export var follow_range: float = 25.0  # 跟隨範圍
@export var jump_height: float = 20.0  # 跳躍高度
@export var sky_attack_cooldown: float = 5.0  # 天降攻擊冷卻時間

var current_health: float
var player: Node = null
var has_encountered_player: bool = false
var is_following: bool = false

# 天降攻擊相關變數
var is_sky_attacking: bool = false
var sky_attack_state: String = "none"  # "jumping", "waiting", "falling"
var sky_attack_timer: float = 0.0
var last_sky_attack_time: float = 0.0
var target_fall_position: Vector3
var original_position: Vector3

@onready var health_bar = $BossUI/Panel/VBoxContainer/BossHealthBar
@onready var name_label = $BossUI/Panel/VBoxContainer/BossName

func _ready() -> void:
	current_health = max_health
	name_label.text = boss_name
	health_bar.update_health(current_health, max_health)
	add_to_group("boss")

	# 尋找玩家
	player = get_tree().get_first_node_in_group("player")

	# 設定碰撞層（用於被玩家攻擊檢測）
	collision_layer = 4  # Boss在層4
	collision_mask = 1 | 2  # 可以碰撞地面(層1)和玩家(層2)

func _physics_process(delta: float) -> void:
	if current_health <= 0 or not player:
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


	# 檢查是否首次遭遇玩家
	if not has_encountered_player and distance <= 15.0:  # 15公尺遭遇距離
		has_encountered_player = true
		take_damage(50.0)  # 遭遇時失去50血量
		print(boss_name + " 發現了玩家！失去50血量！")

	# 檢查是否進入跟隨範圍
	if distance <= follow_range and not is_following:
		is_following = true
		print(boss_name + " 開始跟隨玩家！")

	# 處理天降攻擊
	if is_sky_attacking:
		handle_sky_attack(delta)
	else:
		# 檢查是否可以發動天降攻擊
		var current_time = Time.get_ticks_msec() / 1000.0
		if is_following and distance <= 10.0 and (current_time - last_sky_attack_time) >= sky_attack_cooldown:
			start_sky_attack()

		# 只有在跟隨模式下且不在攻擊狀態才移動
		if is_following:
			# 跟隨玩家但保持一定距離
			var direction = (player.global_position - global_position).normalized()
			direction.y = 0  # 只在水平面移動

			# 保持3-5米的跟隨距離
			if distance > 5.0:
				velocity.x = direction.x * move_speed
				velocity.z = direction.z * move_speed
				look_at(player.global_position)
			else:
				# 太近時停止移動
				velocity.x = 0
				velocity.z = 0
		else:
			# 非跟隨模式時待機
			velocity.x = 0
			velocity.z = 0

	# 應用重力（除非在跳躍階段）
	if not is_on_floor() and sky_attack_state != "jumping":
		velocity.y -= 75 * delta

	move_and_slide()


# 受傷函數
func take_damage(amount: float) -> void:
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	health_bar.update_health(current_health, max_health)
	
	print("%s 受到 %d 點傷害！剩餘血量：%d" % [boss_name, amount, current_health])
	
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

	is_sky_attacking = true
	sky_attack_state = "jumping"
	sky_attack_timer = 0.0
	original_position = global_position

	# 鎖定玩家當前位置作為落地目標
	target_fall_position = player.global_position

	# 開始跳躍
	velocity.y = jump_height
	velocity.x = 0
	velocity.z = 0

	print(boss_name + " 發動天降攻擊！跳躍中...")
	last_sky_attack_time = Time.get_ticks_msec() / 1000.0

# 處理天降攻擊的各個階段
func handle_sky_attack(delta: float) -> void:
	sky_attack_timer += delta

	match sky_attack_state:
		"jumping":
			# 跳躍階段：只在Y軸移動，到達最高點後進入等待
			if velocity.y <= 0:  # 開始下降時切換到等待狀態
				sky_attack_state = "waiting"
				sky_attack_timer = 0.0
				velocity.y = 0  # 懸停在空中
				print(boss_name + " 在空中等待1秒後落下...")

		"waiting":
			# 等待階段：懸停1秒
			velocity.x = 0
			velocity.z = 0
			velocity.y = 0  # 保持懸停

			if sky_attack_timer >= 1.0:  # 1秒後開始下降
				sky_attack_state = "falling"
				sky_attack_timer = 0.0
				print(boss_name + " 開始墜落攻擊！")

		"falling":
			# 下降階段：快速朝向目標位置下降
			var direction_to_target = (target_fall_position - global_position).normalized()
			direction_to_target.y = 0  # 只在水平方向移動到目標

			# 水平移動到目標位置
			velocity.x = direction_to_target.x * move_speed * 2  # 比正常移動快一些
			velocity.z = direction_to_target.z * move_speed * 2

			# 快速下降
			velocity.y = -jump_height * 1.5  # 下降速度比跳躍更快

			# 檢查是否著陸
			if is_on_floor():
				end_sky_attack()

# 結束天降攻擊
func end_sky_attack() -> void:
	is_sky_attacking = false
	sky_attack_state = "none"
	sky_attack_timer = 0.0

	# 落地時對附近玩家造成傷害（如果有傷害系統的話）
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= 3.0:  # 3米範圍內
		print(boss_name + " 的天降攻擊擊中了玩家！")
		# 這裡可以呼叫玩家的受傷函數
		# player.take_damage(100.0)
	else:
		print(boss_name + " 的天降攻擊落空了！")

	print(boss_name + " 天降攻擊結束，回到正常狀態")
