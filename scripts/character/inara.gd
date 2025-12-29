# InaraCharacter.gd - 专门的战斗伦恩
class_name InaraCharacter
extends CharacterNode

func _init():
	character_name = "inara"
	display_name = "伊娜拉"
	expression_list = ["afraid","angry","close_eye","hurt","jeer","mock","normal","Proud","shy","smile","Speechless","surprise","tease"]
	current_expression = "normal"
