extends ProgressBar

# 血量變化時的動畫速度
@export var lerp_speed: float = 5.0
# 是否顯示數值（現在會顯示百分比）
@export var show_numbers: bool = true
# 是否使用三階段顏色（用於Boss）
@export var use_three_stage_colors: bool = false

var target_value: float = 0.0
var actual_max_health: float = 0.0
var current_health: float = 0.0

@onready var label = $Label if has_node("Label") else null

func _ready() -> void:
	min_value = 0
	# max_value會在update_health中設置
	update_label()

func _process(delta: float) -> void:
	# 平滑過渡到目標血量 
	value = lerp(value, target_value, lerp_speed * delta)
	if show_numbers:
		update_label()

# 更新血量
func update_health(current: float, maximum: float) -> void:
	current_health = current
	if actual_max_health != maximum:
		actual_max_health = maximum
		max_value = maximum
		value = current
	target_value = current

	# 根據血量百分比改變顏色
	var health_percent = current / maximum

	if use_three_stage_colors:
		# Boss的三階段顏色系統
		if health_percent > 0.666:
			modulate = Color(0, 1, 0)  # 綠色 (66.7%-100%)
		elif health_percent > 0.333:
			modulate = Color(1, 1, 0)  # 黃色 (33.3%-66.7%)
		else:
			modulate = Color(1, 0, 0)  # 紅色 (0%-33.3%)
	else:
		# 普通的兩階段顏色系統
		if health_percent > 0.5:
			modulate = Color(0, 1, 0)  # 綠色
		elif health_percent > 0.25:
			modulate = Color(1, 1, 0)  # 黃色
		else:
			modulate = Color(1, 0, 0)  # 紅色

# 更新顯示文字（顯示百分比而不是實際數值）
func update_label() -> void:
	if label and actual_max_health > 0:
		var percent = (current_health / actual_max_health) * 100.0
		label.text = "%d%%" % [int(percent)]
