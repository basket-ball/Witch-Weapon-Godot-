# chapter2_ep10.gd - 第二章第10话
extends Node2D

@onready var novel_interface = $NovelInterface

func _ready():
	await get_tree().process_frame
	chapter2_ep10_script()

func play_script():
	pass

func chapter2_ep10_script():
	novel_interface.change_music("res://assets/audio/music/Witch's Confession.mp3")
	novel_interface.change_background("res://assets/images/bg/SID/opsRoom.png")
	novel_interface.show_character("liliu_uniform2","serious")
	await novel_interface.show_dialog("……", "莉琉")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("在小怜离开后，莉琉神色凝重的盯着手持设备。")
	await novel_interface.show_text_only("在莉的眼前展现的，是一长串变化的数据流。")
	await novel_interface.show_text_only("屏幕上那份处于『锁定』状态的档案，正发生着改变。")
	novel_interface.show_character("liliu_uniform2","serious")
	await novel_interface.show_dialog("（怎么会！埃癸斯应该可以防御任何网络攻击）\n（难道是元老院的人……）", "莉琉")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("『怜』的历史记录全都变成了乱码，随着屏幕的闪烁，乱码逐渐被修正为有意义的信息。")
	await novel_interface.show_text_only("从无法解析到逐渐完善，埃癸斯主机外部的攻击性防火墙始终没有任何警告。")
	await novel_interface.show_text_only("莉琉的手表表盘，一个红色的字母“T”在闪烁。")
	novel_interface.show_character("liliu_uniform2","serious")
	await novel_interface.show_dialog("（埃癸斯主机上发生这种规模的数据篡改，只有\n『Themis』注意到了异常吗……）", "莉琉")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("手持设备上，『怜』的历史记录被完全更新了\n从幼儿园、小学到中学都就读于私立学校。")
	await novel_interface.show_text_only("成绩单、毕业证、获奖记录、医疗和保险记录……\n处处都体现着优越富足的家境。")
	await novel_interface.show_text_only("但是前不久少女的双亲和哥哥在海外遭遇事故坠机身亡。")
	novel_interface.show_character("liliu_uniform2","serious")
	await novel_interface.show_dialog("根据《战后儿童保育法》，曾登记为志愿者的SS级科学家被分配成为了少女的监护人……", "莉琉")
	await novel_interface.show_dialog("（不会连我的记录都！）\n（果然……这是在挑衅吗？）", "莉琉")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("教师评语中有这样的内容“总是喜欢模仿哥哥的动作，缺乏作为女孩子的矜持……”")
	novel_interface.show_character("liliu_uniform2","normal2")
	await novel_interface.show_dialog("（伪造到这种程度，真该让信息部门的人好好学\n学）", "莉琉")
	await novel_interface.show_dialog("（如果换别的监护人，就连我也无法分辨真伪了）\n（……是移植了别人的资料吗？）", "莉琉")
	novel_interface.change_expression("serious")
	await novel_interface.show_dialog("（看来总部要好好做一次反窃听扫描了。）", "莉琉")
	novel_interface.change_expression("normal1")
	await novel_interface.show_dialog("（下面还有张照片？……）", "莉琉")
	novel_interface.change_expression("serious")
	await novel_interface.show_dialog("……！！", "莉琉")
	await novel_interface.hide_character()
	novel_interface.show_special_centered_image("res://assets/images/bg/Shot/girlchar_childRedHair.png",308,0.6,0.96,0.3)
	await novel_interface.show_text_only("记录中有一张照片作为附件，是少女双亲的遗物。")
	await novel_interface.show_text_only("照片上，幼时的小怜一头短发，正在得意地展示着她的画作。")
	await novel_interface.show_text_only("女孩画的是小美人鱼，右下角用稚气的字体写着一行英文“I have red hair too”")
	await novel_interface.show_dialog("……", "莉琉")
	await novel_interface.show_dialog("呵呵呵呵，原来是这样吗……", "莉琉")
	await novel_interface.show_dialog("虽然是合成的照片，但小时候的样子还真可爱～", "莉琉")
	await novel_interface.show_dialog("既给她制造了天衣无缝的历史记录。", "莉琉")
	await novel_interface.show_dialog("同时是想提醒我，这个小家伙很特别吧？", "莉琉")
	await novel_interface.show_dialog("你一开始就不打算向我隐瞒。", "莉琉")
	await novel_interface.show_dialog("所以才特意选了这张我小时候画的画——", "莉琉")
	await novel_interface.hide_special_centered_image(0.3)
	novel_interface.show_character("liliu_uniform2","normal2")
	await novel_interface.show_dialog("你要传达信息的就是这些吗……", "莉琉")
	novel_interface.change_expression("speak")
	await novel_interface.show_dialog("埃癸斯……", "莉琉")

	print("=== 第二章第10话结束 ===")

	# 调用剧情结束函数
	await novel_interface.end_story_episode(0.5)
