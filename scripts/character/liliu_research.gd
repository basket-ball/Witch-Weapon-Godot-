# LiliuResearchCharacter.gd
class_name LiliuResearchCharacter
extends CharacterNode

func _init():
	character_name = "liliu_research"
	display_name = "莉琉"
	expression_list = ["angry", "happy", "normal", "shock", "smile", "speak"]
	current_expression = "normal"
