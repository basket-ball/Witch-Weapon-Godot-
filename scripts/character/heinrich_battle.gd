# HeinrichCharacter.gd
class_name HeinrichBattleCharacter
extends CharacterNode

func _init():
	character_name = "heinrich_battle"
	display_name = "海因里希"
	expression_list = ["bored", "mock", "normal", "perspire", "serious", "shout", "smile", "speechless", "worry"]
	current_expression = "normal"
