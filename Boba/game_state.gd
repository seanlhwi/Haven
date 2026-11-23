extends Node

signal ability_unlocked(ability_name: String)

var abilities := {
	"dash": false,
}

# Abilities that survive death (earned for good)
var permanent := {
	"dash": false,
}

func unlock(ability: String) -> void:
	if abilities.has(ability) and not abilities[ability]:
		abilities[ability] = true
		ability_unlocked.emit(ability)

func unlock_permanently(ability: String) -> void:
	if abilities.has(ability):
		permanent[ability] = true
		unlock(ability)

func lock_all() -> void:
	for ability in abilities:
		if not permanent.get(ability, false):
			abilities[ability] = false

func has_ability(ability: String) -> bool:
	return abilities.get(ability, false)
