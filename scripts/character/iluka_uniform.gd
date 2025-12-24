# IlukaUniformCharacter.gd
class_name IlukaUniformCharacter
extends CharacterNode

func _init():
	character_name = "iluka_uniform"
	display_name = "伊露卡"
	expression_list = ["gourmet", "hungry", "normal", "panic", "sleepy", "smile", "speechless", "unhappy", "worry"]
	current_expression = "normal"
