extends Label

# 基础设置
@export_group("Typewriter Settings")
@export var chars_per_second: float = 20.72
@export var auto_start: bool = true

# 音效设置
@export_group("Sound Settings")
@export var typing_sound: AudioStream = preload("res://assets/audio/sound/UI_talk_v1.wav")
@export_range(0.0, 1.0) var sound_volume: float = 1.0
@export var play_sound_on_space: bool = false
@export var silent_char_delay: float = 0.05  # 静音字符的短暂延迟

var full_text: String = ""
var current_char_index: int = 0
var time_accumulator: float = 0.0
var is_typing: bool = false
var skip_next_sound: bool = false

var audio_player: AudioStreamPlayer

signal typing_finished
signal character_typed(character)

func _ready():
	_setup_audio_player()
	
	if auto_start:
		start_typewriter(text)

func _setup_audio_player():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	if typing_sound:
		audio_player.stream = typing_sound
		audio_player.volume_db = linear_to_db(sound_volume)
		audio_player.bus = "SFX"

func start_typewriter(new_text: String):
	full_text = new_text
	text = ""
	current_char_index = 0
	time_accumulator = 0.0
	is_typing = true
	skip_next_sound = false

func _process(delta):
	if not is_typing:
		return
	
	time_accumulator += delta
	var time_per_char = 1.0 / chars_per_second
	
	# 如果当前字符是标点符号，使用更短的延迟
	if current_char_index < full_text.length():
		var next_char = full_text[current_char_index]
		if _is_punctuation(next_char):
			time_per_char = silent_char_delay
	
	while time_accumulator >= time_per_char and current_char_index < full_text.length():
		time_accumulator -= time_per_char
		
		var current_char = full_text[current_char_index]
		current_char_index += 1
		text = full_text.substr(0, current_char_index)
		
		# 发送信号
		character_typed.emit(current_char)
		
		# 播放音效（标点符号不发音）
		if not _is_punctuation(current_char):
			_play_typing_sound(current_char)
		
		# 重置时间间隔为正常速度
		time_per_char = 1.0 / chars_per_second
	
	if current_char_index >= full_text.length():
		is_typing = false
		typing_finished.emit()

func _is_punctuation(character: String) -> bool:
	return character in [".", ",", "!", "?", ";", ":", "、", "，", "。", "！", "？", "；", "："]

func _play_typing_sound(character: String):
	if not audio_player or not typing_sound:
		return
	
	# 跳过特定字符
	if character == " " and not play_sound_on_space:
		return
	if character in ["\n", "\t"]:
		return
	
	# 播放原声，不改变音调
	audio_player.pitch_scale = 1.0
	audio_player.play()

# 其他功能方法...
func skip_typewriter():
	if is_typing:
		text = full_text
		current_char_index = full_text.length()
		is_typing = false
		typing_finished.emit()

func pause_typewriter():
	is_typing = false

func resume_typewriter():
	if current_char_index < full_text.length():
		is_typing = true

func set_volume(volume: float):
	sound_volume = clamp(volume, 0.0, 1.0)
	if audio_player:
		audio_player.volume_db = linear_to_db(sound_volume)

# 完全清除所有文本和状态
func clear_all():
	full_text = ""
	text = ""
	current_char_index = 0
	time_accumulator = 0.0
	is_typing = false
	skip_next_sound = false
