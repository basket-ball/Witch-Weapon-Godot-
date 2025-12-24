# rennudeCharacter.gd
class_name RenNudeCharacter
extends CharacterNode

func _init():
	character_name = "ren_nude"
	display_name = "小怜"
	expression_list = ["indignation","normal","perspire","relax","shame","shock","shy","timid","uneasy"]
	current_expression = "normal"
