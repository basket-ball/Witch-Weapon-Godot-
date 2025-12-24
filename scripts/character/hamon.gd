# HamonCharacter.gd
class_name HamonCharacter
extends CharacterNode

func _init():
	character_name = "hamon"
	display_name = "哈蒙"
	expression_list = ["normal1", "normal2", "serious", "shout", "speak", "unhappy"]
	current_expression = "normal1"
