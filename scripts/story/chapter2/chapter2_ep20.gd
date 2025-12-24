# chapter2_ep20.gd - 第二章第20话
extends Node2D

@onready var novel_interface = $NovelInterface

func _ready():
	await get_tree().process_frame
	chapter2_ep20_script()

func play_script():
	pass

func chapter2_ep20_script():
	novel_interface.change_music("res://assets/audio/music/Hard Stage.mp3")
	novel_interface.change_background("res://assets/images/bg/Shot/BG_City_powerSubstation.png")
	await novel_interface.show_text_only("江森变电所，战前建造的大型露天变电所，后被第一学院都市的江森重工整体收购。")
	await novel_interface.show_text_only("这几年，随着『协约区』的用电需求骤增而不断扩容，如今的容量已经扩大了20倍。")
	await novel_interface.show_text_only("我和安妮从铁丝网的缺口处小心的进入变电所。")
	novel_interface.show_character("ren_battle","worry")
	await novel_interface.show_dialog("这就是定位点了，情况看上去有点糟糕啊……\n我们来晚了吗？", "小怜")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("此时，变电所周围回响着一种电流过载特有的嗡嗡声，电力设备上时不时喷出电火花。")
	await novel_interface.show_text_only("地面和墙壁都有大片的树状灼痕，就像是被雷电侵蚀过……")
	novel_interface.show_character("anne_battle","worry")
	await novel_interface.show_dialog("这里似乎没有之前异变区域的感觉呀，莉琉该不会想让我们来维修变压器吧？", "安妮")
	novel_interface.change_expression("frustrate")
	await novel_interface.show_dialog("物理课的电学部分，我、我最头疼了……", "安妮")
	await novel_interface.hide_character()
	await novel_interface.show_text_only("安妮说话时声音发抖，似乎回想起了被无法分清的左右手定则支配的恐惧。")
	novel_interface.show_character("ren_battle","solemn")
	await novel_interface.show_dialog("等等，你听——\n前面好像……", "小怜")
	novel_interface.change_expression("serious")
	await novel_interface.show_dialog("什么声音？！", "小怜")
	novel_interface.character_move_left(-0.25)
	novel_interface.show_2nd_character("anne_battle","perspire",0.25)
	await novel_interface.show_dialog("在、在上面——", "安妮")
	await novel_interface.hide_all_characters()
	novel_interface.change_music("res://assets/audio/music/Hand-to-hand combat.mp3")
	novel_interface.change_background("res://assets/images/bg/Shot/yiluka_fight0.png")#此处老cg和新cg有不同，但是老cg文件暂时无法寻得
	await novel_interface.show_text_only("我抬起头，看到天上有一名全身电光环绕，手上戴着与体型不相称的金属拳套的蓝发少女——")
	await novel_interface.show_text_only("在她的周围，一群举止怪异的家伙，正在轮番对她发动猛攻。")
	await novel_interface.show_text_only("其中一个女性周身环绕着像鬼火一样的东西。")
	await novel_interface.show_text_only("从咽喉中发出尖锐的咯咯咯的声音，让人本能的感到不悦。")
	await novel_interface.show_text_only("而其他人……或者说无法确定是不是人的存在，似乎被什么支配着。")
	await novel_interface.show_text_only("在一轮轮的猛烈的攻击中，甚至身体也随着攻击的动作扭曲成不可能的角度。")
	novel_interface.change_background("res://assets/images/bg/Shot/BG_City_powerSubstation.png")
	novel_interface.show_character("iluka_battle")
	await novel_interface.show_dialog("呼……哈、哈啊……", "伊露卡")
	novel_interface.character_dark()
	await novel_interface.show_text_only("蓝发的小姑娘被轮番攻击之下\n身上已经伤痕累累，只能勉力招架。")
	await novel_interface.show_text_only("不、与其说是少女，不如说是小女孩……\n毕竟她的外表看上去，只有十岁左右的样子。")
	await novel_interface.show_text_only("……呃，现在是纠结这种细节的时候吗？")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_battle","solemn")
	await novel_interface.show_dialog("安妮，你看——", "小怜")
	await novel_interface.hide_character()
	novel_interface.show_character("witch_second")
	await novel_interface.show_dialog("伟大……的……夕力Duマmーsmrti一ガハラ一\n微光……黄泉……咯咯咯咯……", "疯狂的袭击者") #伟大……的……夕力Důマmーsmrti一ガハラ一\n微光……黄泉……咯咯咯咯……有符号高度bug
	await novel_interface.show_dialog("全部…全部…全部…全部全部全部全部全部全部全部全部全部全部全部全部全部全部全部都！！！", "疯狂的袭击者")
	await novel_interface.hide_character()
	novel_interface.show_character("iluka_battle")
	await novel_interface.show_dialog("呃啊——！", "伊露卡")
	await novel_interface.hide_character()
	novel_interface.show_character("anne_battle","perspire")
	await novel_interface.show_dialog("那个小女孩，看上去快撑不住了！", "安妮")
	novel_interface.character_move_left(-0.25)
	novel_interface.show_2nd_character("ren_battle","shout",0.25)
	await novel_interface.show_dialog("这群家伙——\n给我住手！！", "小怜")

	print("=== 第二章第20话结束 ===")

	# 调用剧情结束函数
	await novel_interface.end_story_episode(0.5)
