# AnneUniformCharacter.gd
class_name AnneBattleCharacter
extends CharacterNode

func _init():
	character_name = "anne_battle"
	display_name = "安妮"
	expression_list = ["frustrate", "gratified", "happy", "normal", "perspire", "smile", "uneasy", "worry"]
	current_expression = "normal"
