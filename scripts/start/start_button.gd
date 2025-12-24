extends TextureButton

# 场景常量定义
const NEXT_SCENE = preload("res://scenes/main/main_menu.tscn")  # 下一个场景：主菜单
const CLICK_SOUND = preload("res://assets/audio/sound/UI_Confirm.wav")  # 点击音效

func _on_pressed() -> void:
	"""处理开始按钮点击事件，播放音效并切换到主菜单场景"""
	# 播放点击音效
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = CLICK_SOUND
	add_child(audio_player)
	audio_player.play()
	
	# 等待音效播放完成后切换场景
	await audio_player.finished
	audio_player.queue_free()
	
	get_tree().change_scene_to_packed(NEXT_SCENE)
