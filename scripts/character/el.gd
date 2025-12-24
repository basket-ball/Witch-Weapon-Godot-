# ElCharacter.gd
class_name ElCharacter
extends CharacterNode

func _init():
	character_name = "el"
	display_name = "艾尔加纳"
	expression_list = ["depressed", "mock", "normal", "sad", "shout", "smile", "surprised"]
	current_expression = "normal"
