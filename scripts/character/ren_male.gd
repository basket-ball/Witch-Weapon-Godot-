# RenMaleCharacter.gd - 专门的战斗伦恩
class_name RenMaleCharacter
extends CharacterNode

func _init():
	character_name = "ren_male"
	display_name = "小怜"
	expression_list = ["happy","hurt","normal","shock","shout","shy","sob","speechless","worry"]
	current_expression = "normal"
