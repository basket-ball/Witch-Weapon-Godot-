extends TextureButton

var original_position: Vector2
var float_distance: float = 6.0
var move_duration: float = 0.3  # 移动时间
var pause_duration: float = 0.3  # 停顿时间

func _ready():
	# 保存原始位置
	original_position = position
	# 开始浮动动画
	start_floating()

func start_floating():
	var tween = create_tween()
	tween.set_loops() # 设置无限循环
	
	# 向下移动 (0.3秒)
	tween.tween_property(self, "position", 
		original_position + Vector2(0, float_distance), 
		move_duration)
	
	# 在底部停顿 (0.3秒)
	tween.tween_interval(pause_duration)
	
	# 返回原位置 (0.3秒)
	tween.tween_property(self, "position", 
		original_position, 
		move_duration)
		
	tween.tween_interval(pause_duration)
