# NyxFullCharacter.gd
class_name NyxFullCharacter
extends CharacterNode

func _init():
	character_name = "nyx_full"
	display_name = "倪克斯"
	expression_list = ["normal1", "normal2", "mock", "sad", "smile", "speak"]
	current_expression = "normal1"
