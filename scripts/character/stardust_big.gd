# StardustBigCharacter.gd
class_name StardustBigCharacter
extends CharacterNode

func _init():
	character_name = "stardust_big"
	display_name = "星尘"
	expression_list = ["cat_mouse","close_eye","normal","smile1","smile2"]
	current_expression = "normal"
