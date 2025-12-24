# CerazaCharacter.gd
class_name CerazaCharacter
extends CharacterNode

func _init():
	character_name = "cereza"
	display_name = "瑟雷莎"
	expression_list = ["blink", "boring", "happy", "jest", "normal", "smile", "speek", "uneasy", "wordless", "yell"]
	current_expression = "normal"
