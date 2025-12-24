# BeatriceRegularCharacter.gd
class_name BeatriceRegularCharacter
extends CharacterNode

func _init():
	character_name = "beatrice_regular"
	display_name = "贝阿特丽切"
	expression_list = ["angry", "astonish", "bored", "grieved", "loathe", "normal", "panic", "sad", "smile1", "smile2", "smile3", "speechless", "worry"]
	current_expression = "smile1"
