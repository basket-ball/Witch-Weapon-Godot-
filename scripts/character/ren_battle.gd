# RenBattleCharacter.gd - 专门的战斗伦恩
class_name RenBattleCharacter
extends CharacterNode

func _init():
	character_name = "ren_battle"
	display_name = "小怜"
	expression_list = ["awkward", "blush", "bored", "cateye", "gratified", "happy", "heart", "normal1", "normal2", "panic", "perspire1", "perspire2", "serious", "shout", "shy", "shy_left", "shy_right", "smile", "sob", "solemn", "speechless", "sprite", "stare", "timid", "uneasy", "upset", "wail", "worry", "wry_smile"]
	current_expression = "normal1"
