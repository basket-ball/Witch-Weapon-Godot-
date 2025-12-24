# RenUniformCharacter.gd
class_name RenUniformCharacter
extends CharacterNode

func _init():
	character_name = "ren_uniform"
	display_name = "小怜"
	expression_list = ["awkward", "blush", "bored", "gratified", "happy", "heart", "normal1", "normal2", "panic", "perspire1", "perspire2", "serious", "shout", "shy", "shy_left", "shy_right", "smile", "sob", "solemn", "speechless", "sprite", "stare", "timid", "uneasy", "upset", "wail", "worry", "wry_smile"]
	current_expression = "normal1"
