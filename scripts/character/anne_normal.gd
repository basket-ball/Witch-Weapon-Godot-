# AnneUniformCharacter.gd
class_name AnneNormalCharacter
extends CharacterNode

func _init():
	character_name = "anne_normal"
	display_name = "安妮"
	expression_list = ["frustrate", "happy", "normal1", "normal2", "panic", "relieve", "serious", "shy", "smile", "stare", "unhappy", "upset", "worry"]
	current_expression = "normal1"
