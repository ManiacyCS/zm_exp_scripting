#include <amxmodx>
#include <zp50_class_human>

// Classic Human Attributes
new const humanclass1_name[] = "Pudzian"
new const humanclass1_info[] = "=HP++ Armor+="
new const humanclass1_models[][] = { "csfifkaczlo" }
const humanclass1_health = 300
const Float:humanclass1_speed = 1.0
const Float:humanclass1_gravity = 1.0
const humanclass1_armor = 35

new g_HumanClassID

public plugin_precache()
{
	register_plugin("[ZP] Class: Human: Classic", ZP_VERSION_STRING, "ZP Dev Team")
	
	g_HumanClassID = zp_class_human_register(humanclass1_name, humanclass1_info, humanclass1_health, humanclass1_speed, humanclass1_gravity, humanclass1_armor)
	new index
	for (index = 0; index < sizeof humanclass1_models; index++)
		zp_class_human_register_model(g_HumanClassID, humanclass1_models[index])
}
