# AICharacter.gd
class_name AICharacter
extends CharacterNode

func _init():
	character_name = "ai"
	display_name = "爱衣"
	expression_list = ["blush", "blush_dizzy", "blush_stare", "blush_think", "blush_wink", "dizzy", "normal", "stare", "think", "wink"]
	current_expression = "normal"
