# SoyaNunCharacter.gd
class_name SoyaNunCharacter
extends CharacterNode

func _init():
	character_name = "soya_nun"
	display_name = "索娅"
	expression_list = ["afraid", "cry", "jest", "laugh", "normal", "relieve", "shy", "smile", "snivel", "speechless", "trance", "wordless", "worry", "yell"]
	current_expression = "normal"
