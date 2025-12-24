# ShiCharacter.gd
class_name ShiCharacter
extends CharacterNode

func _init():
	character_name = "shi"
	display_name = "施教授"
	expression_list = ["angry", "eyeclose", "normal", "shout", "speak"]
	current_expression = "normal"
