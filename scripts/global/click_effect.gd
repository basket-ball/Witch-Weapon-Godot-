extends Node

var click_effect_scene = preload("res://scenes/global/clickeffect.tscn")
var click_effect_layer: CanvasLayer

func _ready():
	process_priority = 100
	_create_click_effect_layer()

func _create_click_effect_layer():
	# 创建专用的CanvasLayer用于显示点击效果
	click_effect_layer = CanvasLayer.new()
	click_effect_layer.layer = 100  # 设置高层级确保在所有UI之上
	get_tree().current_scene.add_child(click_effect_layer)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			spawn_click_effect(event.position)

func spawn_click_effect(position):
	# 确保CanvasLayer存在且有效
	if not click_effect_layer or not is_instance_valid(click_effect_layer):
		_create_click_effect_layer()
	
	var effect = click_effect_scene.instantiate()
	click_effect_layer.add_child(effect)
	effect.global_position = position
	
	# 播放点击音效
	var audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = load("res://assets/audio/sound/UI_Click2.wav")
	effect.add_child(audio_player)
	audio_player.play()
	
	# 获取粒子系统
	var particles = effect.get_node_or_null("SmallStars")
	if particles:
		# 随机设置第一批粒子数量(4-7个)
		var first_batch = randi_range(4, 7)
		particles.amount = first_batch
		particles.emitting = true
