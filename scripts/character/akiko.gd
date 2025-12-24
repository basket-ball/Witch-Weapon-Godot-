# AkikoCharacter.gd
class_name AkikoCharacter
extends CharacterNode

func _init():
	character_name = "akiko"
	display_name = "秋子"
	expression_list = ["normal", "perspire", "serious", "shock", "shy"]
	current_expression = "normal"
