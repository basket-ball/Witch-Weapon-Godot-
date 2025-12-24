# LiliuUniform1Character.gd
class_name LiliuUniform1Character
extends CharacterNode

func _init():
	character_name = "liliu_uniform1"
	display_name = "莉琉"
	expression_list = ["angry", "jest", "normal1", "normal2", "serious", "sigh", "speak"]
	current_expression = "normal1"
