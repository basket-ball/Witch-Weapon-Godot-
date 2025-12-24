# AnneUniformCharacter.gd
class_name FabiolaMaidCharacter
extends CharacterNode

func _init():
	character_name = "fabiola_maid"
	display_name = "法贝拉"
	expression_list = ["blush", "confident", "laugh", "mock", "normal", "panic", "perspire", "smile", "thinking"]
	current_expression = "normal"
