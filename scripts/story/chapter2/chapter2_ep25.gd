# chapter2_ep25.gd - 第二章第25话
extends Node2D

@onready var novel_interface = $NovelInterface

func _ready():
	await get_tree().process_frame
	chapter2_ep25_script()

func play_script():
	pass

func chapter2_ep25_script():
	novel_interface.change_music("res://assets/audio/music/Sewer.mp3")
	await novel_interface.show_text_only("这是哪里？\n周围弥漫着厚重的浓雾，远方似乎站着一个人。")
	novel_interface.show_character("ren_behind1")
	await novel_interface.show_dialog("怜……", "黑影")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("……是谁？")
	await novel_interface.show_text_only("那道身影逐渐向我走来……")
	await novel_interface.show_text_only("那是一名穿着黑色奇怪装束的家伙，一双冷淡的浅红色眸子……")
	novel_interface.show_character("ren_behind2")
	await novel_interface.show_text_only("在那股眼神之中，似是一丝狡猾的笑意。")
	await novel_interface.show_text_only("——那个人，令我有一种非常熟悉的感受。")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_behind3")
	await novel_interface.show_dialog("直到……之时……终将……", "黑影")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("你说什么？\n喂——！等等！")
	await novel_interface.show_text_only("……")
	novel_interface.change_background("res://assets/images/bg/APT/bedRoom.png")
	await novel_interface.show_dialog("啊——！", "小怜")
	novel_interface.change_music("res://assets/audio/music/Sunset.mp3")
	await novel_interface.show_text_only("窗外还是凌晨，太阳还未升起。天边只有一抹柔和的红光。")
	await novel_interface.show_text_only("昨天太过劳累，我没换衣服就睡倒在床上。所以才做了那个梦吗……")
	await novel_interface.show_text_only("我睁开眼试图回忆起梦里的场景，却无论如何都想不起他究竟说了什么。")
	await novel_interface.show_dialog("怎么会做这种梦，总有种不好的预感。", "小怜")
	novel_interface.show_character("anne_uniform","panic")
	await novel_interface.show_dialog("啊！你已经醒了吗？", "安妮")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_sleep")
	await novel_interface.show_dialog("安妮……你起来的好早呢。", "小怜")
	await novel_interface.hide_character()
	novel_interface.show_character("anne_uniform","panic")
	await novel_interface.show_dialog("出事了！莉琉刚才打电话来叫我们看邮件里的新\n闻！", "安妮")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_sleep")
	await novel_interface.show_dialog("嗯，好的！\n真是不让人休息啊……", "小怜")
	await novel_interface.show_dialog("（太好了，安妮还是和平时一样）\n（那果然只是个普通的梦。）", "小怜")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("我松了口气，匆匆换上衣服坐到电脑旁，点开莉琉发到邮件里的新闻链接。")
	novel_interface.show_character("ren_uniform","speechless")
	await novel_interface.show_dialog("又有『异质物』失窃啦，真是不太平……", "小怜")
	novel_interface.change_expression("sprite")
	await novel_interface.show_dialog("不过这不是第二学园都市嘛，关SID什么事嘛\n而且……", "小怜")
	novel_interface.change_expression("solemn")
	await novel_interface.show_dialog("……等等，这是什么？！", "小怜")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("虽然是凌晨，但世界各地的网站的头条全部更新了同样内容新闻。")
	novel_interface.change_music("res://assets/audio/music/Deep Water.mp3")
	novel_interface.change_background("res://assets/images/bg/Shot/boySP_news.png")
	await novel_interface.show_text_only("神秘男性闯入阿卡特拉兹收容基地，夺走该基地收容的EX级古代『异质物』")
	await novel_interface.show_text_only("发布通缉信息如下—性别：男性 年龄：15-18岁目前只有一张照片。")
	await novel_interface.show_text_only("……")
	await novel_interface.show_text_only("通缉令中嫌疑犯的长相，我再熟悉不过了。")
	await novel_interface.show_dialog("这是……我？", "小怜")
	await novel_interface.show_text_only("确切来说，那是我还是男生时的样子。")
	await novel_interface.show_text_only("通缉令中，该男子抢走的异质物并未公开，只是将他的危险等级定为AAA。")
	novel_interface.change_background("res://assets/images/bg/APT/bedRoom.png")
	await novel_interface.show_text_only("……为什么会这样？")
	novel_interface.show_character("ren_uniform","solemn")
	await novel_interface.show_dialog("到底……发生了什么？", "小怜")

	print("=== 第二章第25话结束 ===")

	# 调用剧情结束函数
	await novel_interface.end_story_episode(0.5)
