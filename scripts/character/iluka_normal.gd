# IlukaNormalCharacter.gd
class_name IlukaNormalCharacter
extends CharacterNode

func _init():
	character_name = "iluka_normal"
	display_name = "伊露卡"
	expression_list = ["gourmet", "hungry", "normal", "panic", "sleepy", "smile", "speechless", "unhappy", "worry"]
	current_expression = "normal"
