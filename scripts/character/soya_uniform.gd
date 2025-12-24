# SoyaUniformCharacter.gd
class_name SoyaUniformCharacter
extends CharacterNode

func _init():
	character_name = "soya_uniform"
	display_name = "索娅"
	expression_list = ["afraid", "cry", "jest", "laugh", "normal", "relieve", "shy", "smile", "snivel", "speechless", "trance", "wordless", "worry", "yell"]
	current_expression = "normal"
