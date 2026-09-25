class_name Chapter00Director
extends Node

signal checkpoint_changed(id)
signal route_changed(id)
signal cell_changed(id)

const ROUTE := ["awakening", "cemetery", "hound", "ruins", "armless", "temple_reveal", "shield_boss", "temple_gate"]
const ROUTE_CELL := {
	"awakening":"CEM_01", "cemetery":"CEM_01", "hound":"CEM_01",
	"ruins":"RUIN_01", "armless":"RUIN_01",
	"temple_reveal":"TEMPLE_EXT_01", "shield_boss":"TEMPLE_EXT_01", "temple_gate":"TEMPLE_EXT_01"
}
var route_index := 0
var checkpoint := "awakening"
var current_cell := "CEM_01"

func advance() -> void:
	set_route_index(route_index + 1)

func set_route_index(index: int) -> void:
	route_index = clampi(index, 0, ROUTE.size() - 1)
	var id: String = ROUTE[route_index]
	emit_signal("route_changed", id)
	var next_cell: String = ROUTE_CELL[id]
	if next_cell != current_cell:
		current_cell = next_cell
		emit_signal("cell_changed", current_cell)

func set_checkpoint(id: String) -> void:
	checkpoint = id
	emit_signal("checkpoint_changed", id)

func current_route() -> String:
	return ROUTE[route_index]

func mark_exterior_encounter_cleared(id:String)->void:
	match id:
		"hound":
			set_route_index(ROUTE.find("ruins"))
		"armless":
			set_route_index(ROUTE.find("temple_reveal"))
		"shield_boss":
			set_route_index(ROUTE.find("temple_gate"))

func mark_temple_reveal_seen()->void:
	set_route_index(ROUTE.find("shield_boss"))
