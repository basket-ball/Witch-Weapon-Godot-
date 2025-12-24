# rennudeCharacter.gd
class_name RenNude2Character
extends CharacterNode

func _init():
	character_name = "ren_nude2"
	display_name = "小怜"
	expression_list = ["normal", "shame", "shock", "shy", "uneasy"]
	current_expression = "normal"
