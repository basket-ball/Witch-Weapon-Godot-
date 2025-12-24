# AugustaCharacter.gd
class_name AugustaCharacter
extends CharacterNode

func _init():
	character_name = "augusta"
	display_name = "奥古斯塔"
	expression_list = ["serious", "uneasy", "happy", "normal", "timid", "worry", "shock", "panic", "tear", "wordless", "shout", "smile", "gratified", "stare", "jest"]
	current_expression = "normal"
