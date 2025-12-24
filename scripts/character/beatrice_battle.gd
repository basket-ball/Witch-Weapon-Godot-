# BeatriceBattleCharacter.gd
class_name BeatriceBattleCharacter
extends CharacterNode

func _init():
	character_name = "beatrice_battle"
	display_name = "贝阿特丽切"
	expression_list = ["angry", "astonish", "normal", "smile1", "smile2", "smile3", "speechless", "worry"]
	current_expression = "smile1"
