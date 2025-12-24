# RaphaelCharacter.gd
class_name RaphaelCharacter
extends CharacterNode

func _init():
	character_name = "raphael"
	display_name = "拉斐尔"
	expression_list = ["angry", "jeer", "mock", "normal1", "normal2", "perspire", "smile", "stare", "subtle", "thinking", "worry"]
	current_expression = "normal1"
