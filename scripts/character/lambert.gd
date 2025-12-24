# LambertCharacter.gd
class_name LambertCharacter
extends CharacterNode

func _init():
	character_name = "lambert"
	display_name = "兰伯特"
	expression_list = ["frown", "relax", "sedation", "serious", "smile", "surprise", "usually"]
	current_expression = "sedation"
