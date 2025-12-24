# NantetsuCharacter.gd
class_name NantetsuCharacter
extends CharacterNode

func _init():
	character_name = "nantetsu"
	display_name = "南哲"
	expression_list = ["serious", "smile", "speak"]
	current_expression = "serious"
