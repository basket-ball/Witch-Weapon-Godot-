# chapter2_ex01.gd - 第二章番外1
extends Node2D

@onready var novel_interface = $NovelInterface

func _ready():
	await get_tree().process_frame
	chapter2_ex01_script()

func play_script():
	pass

func chapter2_ex01_script():
	novel_interface.change_music("res://assets/audio/music/Chaostic Daily.mp3")
	novel_interface.change_background("res://assets/images/bg/SID/opsRoom.png")
	novel_interface.show_character("ai","normal")
	await novel_interface.show_dialog("哼哼~到了考察培训成果的时候了！", "爱衣")
	novel_interface.change_expression("stare")
	await novel_interface.show_dialog("来，先把这些口红和对应的颜色名称连起来！", "爱衣")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_battle","panic")
	await novel_interface.show_dialog("噫？这、这……这九只口红……\n不都是红色的吗！？", "小怜")
	novel_interface.change_expression("bored")
	await novel_interface.show_dialog("等等，好像这几只是紫色？", "小怜")
	await novel_interface.hide_character()
	novel_interface.show_character("ai","normal")
	await novel_interface.show_dialog("呃，连接得……完全不对！！", "爱衣")
	await novel_interface.show_dialog("桃粉、珊瑚粉、洋红、樱桃红、紫红、淡紫、葡萄紫、薰衣草紫这么基本的颜色都分不清楚，0分！", "爱衣")
	novel_interface.change_expression("stare")
	await novel_interface.show_dialog("这些口红里，哪一只是yyl这次情人节的限量款？这次可是送分题。", "爱衣")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_uniform","wry_smile")
	await novel_interface.show_dialog("哎？上面没有商标啊……\n情人节的话，是这个有小桃心的？", "小怜")
	await novel_interface.hide_character()
	novel_interface.show_character("ai","normal")
	await novel_interface.show_dialog("居然选了最便宜的一款，情人节送给女孩子相当于当场绝交。0分！", "爱衣")
	novel_interface.change_expression("stare")
	await novel_interface.show_dialog("填空题看来也没指望了，写下MEC这款唇膏的质地~", "爱衣")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_uniform","wry_smile")
	await novel_interface.show_dialog("质地……好像叫天鹅绒？\n不对……丝绸？", "小怜")
	novel_interface.change_expression("shy")
	await novel_interface.show_dialog("啊！那个词叫什么来的？\n明明背过却完全记不起来了！可恶！", "小怜")
	await novel_interface.hide_character()
	novel_interface.show_character("ai","stare")
	await novel_interface.show_dialog("哎~这孩子真是没天分……！", "爱衣")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_uniform","wail")
	await novel_interface.show_dialog("本来就不应该有天分啊！", "小怜")
	await novel_interface.hide_character()
	novel_interface.show_character("ai","normal")
	await novel_interface.show_dialog("我们再最后试试看……", "爱衣")
	novel_interface.change_expression("stare")
	await novel_interface.show_dialog("第一款合成花香调香水叫什么名字，专柜价格是多少！", "爱衣")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_uniform","wry_smile")
	await novel_interface.show_dialog("呃呃……这部分完全忘记了！\n拿香水最没办法了~~", "小怜")
	novel_interface.change_expression("wail")
	await novel_interface.show_dialog("价格……这么一小瓶…\n大概……50块钱？", "小怜")
	await novel_interface.hide_character()
	novel_interface.show_character("liliu_uniform2","normal2")
	await novel_interface.show_dialog("噗嗤~", "莉琉")
	await novel_interface.hide_character()
	novel_interface.show_character("ai","normal")
	await novel_interface.show_dialog("错错错！\n唉……你这方面还真是一点都不灵光啊！", "爱衣")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_uniform","sob")
	await novel_interface.show_dialog("呜呜……", "小怜")
	await novel_interface.hide_character()
	novel_interface.show_character("liliu_uniform2","speak2")
	await novel_interface.show_dialog("噗哈哈哈哈哈哈。", "莉琉")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_uniform","awkward")
	await novel_interface.show_dialog("莉琉！！！你还笑话我！", "小怜")

	print("=== 第二章番外1结束 ===")

	# 调用剧情结束函数
	await novel_interface.end_story_episode(0.5)
