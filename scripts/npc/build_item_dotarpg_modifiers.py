
def main():
	# Map of properties
	propertyMap = {
	#	"damage"	: "MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE",
		"damage"	: "MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE",
		"str"		: "MODIFIER_PROPERTY_STATS_STRENGTH_BONUS",
		"agi"		: "MODIFIER_PROPERTY_STATS_AGILITY_BONUS",
		"int"		: "MODIFIER_PROPERTY_STATS_INTELLECT_BONUS",
		"as"		: "MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT",
		"armor"		: "MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS",
		"mr"		: "MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS",
		"hp"		: "MODIFIER_PROPERTY_HEALTH_BONUS",
		"mana"		: "MODIFIER_PROPERTY_MANA_BONUS",
		"hpreg"		: "MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT",
		"manareg"	: "MODIFIER_PROPERTY_MANA_REGEN_PERCENTAGE",
		"ms"		: "MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT"
	}

	# Open file
	file = open( "items/items_dotarpg_modifiers.txt", "w" )
	
	# Build
	for k,v in propertyMap.iteritems():
		file.write('\t//=================================================================================================================\n')
		file.write('\t// ' + k + ' modifier\n')
		file.write('\t//=================================================================================================================\n')
		file.write('\t"item_dotarpg_modifiers_' + k + '"\n')
		file.write('\t{\n')
		file.write('\t\t"BaseClass"\t\t\t\t"item_datadriven"\n')
		file.write('\t\t"AbilityBehavior"\t\t"DOTA_ABILITY_BEHAVIOR_NO_TARGET | DOTA_ABILITY_BEHAVIOR_IMMEDIATE"\n')
		file.write('\n')
		file.write('\t\t"Modifiers"\n')
		file.write('\t\t{\n')
		
		for i in range(0, 16):
			value = 1 << i
			file.write('\t\t\t"dotarpg_' + k + '_' + str(value) + '"\n')
			file.write('\t\t\t{\n')
			file.write('\t\t\t\t"IsHidden"\t"1"\n')
			file.write('\t\t\t\t"Properties"\n')
			file.write('\t\t\t\t{\n')
			file.write('\t\t\t\t\t"' + v + '"\t"' + str(value) + '"\n')
			file.write('\t\t\t\t}\n')
			file.write('\t\t\t}\n')
		
		file.write('\t\t}\n')
		file.write('\t}\n')
		file.write('\n')


if __name__ == "__main__":
	main()
