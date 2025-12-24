# RenTransCharacter.gd - 专门的战斗伦恩
class_name RenTransCharacter
extends CharacterNode

func _init():
	character_name = "ren_trans"
	display_name = "小怜"
	expression_list = ["normal", "shock", "shy", "stare"]
	current_expression = "normal"
