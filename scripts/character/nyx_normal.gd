# NyxNormalCharacter.gd
class_name NyxNormalCharacter
extends CharacterNode

func _init():
	character_name = "nyx_normal"
	display_name = "倪克斯"
	expression_list = ["normal1", "normal2", "mock", "sad", "smile", "speak"]
	current_expression = "normal1"
