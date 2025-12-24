# AnneUniformCharacter.gd
class_name MilkAimCharacter
extends CharacterNode

func _init():
	character_name = "milk_aim"
	display_name = "牛奶"
	expression_list = ["gratified", "hurt", "laugh", "mock", "normal", "pleased", "serious", "shock", "solemn", "sprite"]
	current_expression = "normal"
