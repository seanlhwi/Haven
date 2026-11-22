extends Node

signal ability_unlocked(ability_name: String)

var abilities := {
	"dash": false,
}

func unlock(ability: String) -> void:
	if abilities.has(ability) and not abilities[ability]:
		abilities[ability] = true
		ability_unlocked.emit(ability)

func has_ability(ability: String) -> bool:
	return abilities.get(ability, false)
