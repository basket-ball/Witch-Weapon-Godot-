# AnneUniformCharacter.gd
class_name BaizhuBreakCharacter
extends CharacterNode

func _init():
	character_name = "baizhu_break"
	display_name = "白烛"
	expression_list = ["angry", "cry", "mock", "normal", "puzzled", "sad", "shock", "shy", "smile", "sob", "speechless", "stare", "tear", "think"]
	current_expression = "normal"
