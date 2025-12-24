# ValkyrjaCharacter.gd
class_name ValkyrjaCharacter
extends CharacterNode

func _init():
	character_name = "valkyrja"
	display_name = "瓦尔基里"
	expression_list = ["angry", "blush", "happy", "normal", "normal2", "panic", "shy", "speak", "speechless", "wink"]
	current_expression = "normal"
