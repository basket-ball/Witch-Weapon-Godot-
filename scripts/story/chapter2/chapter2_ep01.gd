# chapter2_ep01.gd - 第二章第1话
extends Node2D

@onready var novel_interface = $NovelInterface

func _ready():
	await get_tree().process_frame
	chapter2_ep01_script()

func play_script():
	pass

func chapter2_ep01_script():
	novel_interface.change_music("res://assets/audio/music/Conspiracy.mp3")
	novel_interface.change_background("res://assets/images/bg/SID/spSoundChannel.png")
	await novel_interface.show_dialog("你说什么！『埃癸斯』的防御范围内明明属于我们都市防卫厅（MD）的管辖范围！", "防卫厅长官")
	await novel_interface.show_dialog("你们凭什么要接管指挥权？\n不拿出让人信服的理由，休想解除警视封锁！！", "防卫厅长官")
	await novel_interface.show_dialog("这是机密，我不能也没必要向你说明！", "军方长官")
	await novel_interface.show_dialog("现在已经是我们军方的事务了。\n请你们配合！", "军方长官")
	await novel_interface.show_dialog("我不同意！这是防卫厅指挥的行动！！\n除非有元老院的行政令……！", "防卫厅长官")
	await novel_interface.show_dialog("咳咳，我说……", "女性的声音")
	await novel_interface.show_dialog("你们还在这种无聊的事上浪费时间啊？", "女性的声音")
	await novel_interface.show_dialog("这个声音是——\n莉琉……莉琉长官？！", "军方长官")
	await novel_interface.show_dialog("长、长官好！", "军方长官")
	await novel_interface.show_dialog("秘密情报局早就从军方独立了，就不用叫我长官\n了。", "莉琉")
	await novel_interface.show_dialog("莉琉……哼！", "防卫厅长官")
	await novel_interface.show_dialog("这可是4级的加密通讯！！\n你是怎么……", "防卫厅长官")
	await novel_interface.show_dialog("先别管这种小事啦～\n还是想想如何处理现在的问题吧！", "莉琉")
	await novel_interface.show_dialog("既然是4级加密就给我实话实说，又不会有其他人听到——", "莉琉")
	await novel_interface.show_dialog("情报一律公开！！", "莉琉")
	await novel_interface.show_dialog("啊、是！长官！", "军方长官")
	await novel_interface.show_dialog("目前研究中心周围的监控系统出现了大量杂讯，并且检测到了大规模的异常时空波动……", "军方长官")
	await novel_interface.show_dialog("时空波动？\n那是……？", "防卫厅长官")
	await novel_interface.show_dialog("《学园都市灾害对策法》说的很明确了吧……", "莉琉")
	await novel_interface.show_dialog("难道因为是不对公众开放的机密条例\n所以连防卫厅也不看了吗？", "莉琉")
	await novel_interface.show_dialog("唔……难道是……\n关于『异质物』收容失效部分的……？", "防卫厅长官")
	await novel_interface.show_dialog("再加上昨晚『洛斯金杯』突然消失的状况……", "莉琉")
	await novel_interface.show_dialog("……已经有六年没发生过这种事了吧？", "莉琉")
	await novel_interface.show_dialog("要考虑最糟的可能性——", "莉琉")
	await novel_interface.show_dialog("我、我明白了……", "防卫厅长官")
	await novel_interface.show_dialog("我们立刻解除内层封锁，并以演习的名义进行疏散\n……", "防卫厅长官")
	await novel_interface.show_dialog("好，军方在外围部署的如何了？", "莉琉")
	await novel_interface.show_dialog("特殊作战部队正在异变区域周围两公里范围内部署重火力，但现在还无法确认威胁等级。", "军方长官")
	await novel_interface.show_dialog("报导管制呢？", "莉琉")
	await novel_interface.show_dialog("按照协议，正在执行C-13剧本。", "军方长官")
	await novel_interface.show_dialog("好，那么现在开始由秘密情报局（SID）接管异变核心区。", "莉琉")
	await novel_interface.show_dialog("你们也马上行动！", "莉琉")
	await novel_interface.show_dialog("是！", "军方通讯")
	await novel_interface.show_dialog("好、好吧……\n你们自己小心。", "防卫厅长官")

	print("=== 第二章第1话结束 ===")

	# 调用剧情结束函数
	await novel_interface.end_story_episode(0.5)
