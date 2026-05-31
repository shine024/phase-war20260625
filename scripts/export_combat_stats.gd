extends SceneTree
## 导出所有战斗卡数据到控制台

const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")

func _init():
	var cards = DefaultCards.create_all()
	var combat_kind_names = ["轻装", "装甲", "空中", "堡垒"]
	var era_names = ["一战", "二战", "冷战", "现代", "近未来"]
	
	
	var count = 0
	for c in cards:
		if c.card_type == GC.CardType.COMBAT_UNIT:
			var era_name = era_names[c.era] if c.era >= 0 and c.era < era_names.size() else str(c.era)
			var kind_name = combat_kind_names[c.combat_kind] if c.combat_kind >= 0 and c.combat_kind < combat_kind_names.size() else str(c.combat_kind)
			
			var line = "%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d" % [
				c.card_id, c.display_name, era_name, kind_name, c.power, c.base_hp,
				c.deploy_speed, c.range_value, c.energy_cost
			]
			
			# 对轻装
			line += "\t%d\t%.2f\t%.2f\t%.2f" % [c.attack_light, c.attack_light_speed, c.attack_light_windup, c.attack_light_active]
			# 对装甲
			line += "\t%d\t%.2f\t%.2f\t%.2f" % [c.attack_armor, c.attack_armor_speed, c.attack_armor_windup, c.attack_armor_active]
			# 对空
			line += "\t%d\t%.2f\t%.2f\t%.2f" % [c.attack_air, c.attack_air_speed, c.attack_air_windup, c.attack_air_active]
			# 防御
			line += "\t%d\t%d\t%d" % [c.defense_light, c.defense_armor, c.defense_air]
			
			count += 1
	
	quit()  # 退出引擎
