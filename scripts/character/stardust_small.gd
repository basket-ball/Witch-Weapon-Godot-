# StardustSmallCharacter.gd
class_name StardustSmallCharacter
extends CharacterNode

func _init():
	character_name = "stardust_small"
	display_name = "小星尘"
	expression_list = ["disgust", "happy", "konata_eye", "normal1", "normal2", "panic", "pleased", "smile", "stare", "tear", "uneasy", "wordless"]
	current_expression = "normal1"
