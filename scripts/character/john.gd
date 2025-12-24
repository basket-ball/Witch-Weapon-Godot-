# JohnCharacter.gd
class_name JohnCharacter
extends CharacterNode

func _init():
	character_name = "john"
	display_name = "约翰"
	expression_list = ["normal", "perspire", "shy", "smile", "speak", "stare", "worry"]
	current_expression = "normal"
