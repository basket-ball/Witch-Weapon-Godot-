# chapter2_ex03.gd - 第二章番外篇03
extends Node2D

@onready var novel_interface = $NovelInterface

func _ready():
	await get_tree().process_frame
	chapter2_ex03_script()

func play_script():
	pass

func chapter2_ex03_script():
	novel_interface.change_music("res://assets/audio/music/Chaostic Daily.mp3")
	novel_interface.change_background("res://assets/images/bg/APT/washingRoom.png")
	await novel_interface.show_dialog("这儿的浴缸还真是不错啊\n莉琉真是不在乎花钱的性格……", "小怜")
	novel_interface.show_character("ren_nude2","normal")
	await novel_interface.show_dialog("啊~~~~\n折腾了一天躺在浴缸里，最能舒缓身心了~~", "小怜")
	novel_interface.change_expression("uneasy")
	await novel_interface.show_dialog("嗯……", "小怜")
	await novel_interface.show_dialog("这就是……我的身体吗", "小怜")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("皮肤白嫩得有些陌生……\n摸起来还滑滑的……")
	novel_interface.show_character("ren_nude","shame")
	await novel_interface.show_dialog("啊！我在做什么啊！\n哎，接受现实吧", "小怜")
	novel_interface.change_expression("uneasy")
	await novel_interface.show_dialog("毕竟在找到恢复原状的办法之前\n这就是我的身体……", "小怜")
	novel_interface.change_expression("relax")
	await novel_interface.show_dialog("不过跟莫名出现的敌人战斗了一整天，泡个澡真是好舒服啊~", "小怜")
	await novel_interface.show_dialog("认真擦洗一下吧……今天好疲劳~~", "小怜")
	novel_interface.change_expression("timid")
	await novel_interface.show_dialog("嗯啊~~~~~", "小怜")
	novel_interface.change_expression("perspire")
	await novel_interface.show_dialog("依然无法适应自己的声音，发出了小猫呻吟一样的叫声……", "小怜")
	await novel_interface.show_dialog("该死，这声音，听起来还真……", "小怜")
	novel_interface.change_expression("uneasy")
	await novel_interface.show_dialog("下流……", "小怜")
	novel_interface.change_expression("indignation")
	await novel_interface.show_dialog("唔……", "小怜")
	await novel_interface.show_dialog("怎么可能适应啊……这个身体！！", "小怜")

	print("=== 第二章番外篇03结束 ===")

	# 调用剧情结束函数
	await novel_interface.end_story_episode(0.5)
