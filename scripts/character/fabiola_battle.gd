# AnneUniformCharacter.gd
class_name FabiolaBattleCharacter
extends CharacterNode

func _init():
	character_name = "fabiola_battle"
	display_name = "法贝拉"
	expression_list = ["angry", "bored", "mock", "normal", "panic", "perspire", "sad", "sob2", "sob", "thinking", "timid", "wink"]
	current_expression = "normal"
