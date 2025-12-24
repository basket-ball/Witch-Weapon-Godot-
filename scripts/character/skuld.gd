# SkuldCharacter.gd
class_name SkuldCharacter
extends CharacterNode

func _init():
	character_name = "skuld"
	display_name = "斯库尔德"
	expression_list = ["normal", "painful", "panic", "perspire", "pleased", "proud", "smile", "stare", "talk", "think", "thought", "worry"]
	current_expression = "normal"
