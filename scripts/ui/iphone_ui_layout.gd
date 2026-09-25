class_name IPhoneUILayout
extends Node

const COMBAT_SIZE:=Vector2(536,196)
const SETTINGS_BUTTON_SIZE:=Vector2(196,56)
const ROOM5_SIZE:=Vector2(700,236)
const TOAST_SIZE:=Vector2(1040,90)

@onready var combat_panel:Control=get_parent().get_node("CombatHUD/Panel")
@onready var settings_button:Control=get_parent().get_node("CombatHUD/SettingsButton")
@onready var room5_panel:Control=get_parent().get_node("MultiTargetHUD/Panel")
@onready var toast_panel:Control=get_parent().get_node("StoryToast/Panel")

func _ready()->void:
	get_viewport().size_changed.connect(apply_safe_area)
	call_deferred("apply_safe_area")

func apply_safe_area()->void:
	var m:=MobileSafeArea.current(get_viewport())

	combat_panel.offset_right=-m.z
	combat_panel.offset_left=combat_panel.offset_right-COMBAT_SIZE.x
	combat_panel.offset_bottom=-m.w
	combat_panel.offset_top=combat_panel.offset_bottom-COMBAT_SIZE.y

	settings_button.offset_right=-m.z
	settings_button.offset_left=settings_button.offset_right-SETTINGS_BUTTON_SIZE.x
	settings_button.offset_top=m.y
	settings_button.offset_bottom=settings_button.offset_top+SETTINGS_BUTTON_SIZE.y

	room5_panel.offset_left=-ROOM5_SIZE.x*0.5
	room5_panel.offset_right=ROOM5_SIZE.x*0.5
	room5_panel.offset_bottom=-m.w
	room5_panel.offset_top=room5_panel.offset_bottom-ROOM5_SIZE.y

	toast_panel.offset_left=-TOAST_SIZE.x*0.5
	toast_panel.offset_right=TOAST_SIZE.x*0.5
	toast_panel.offset_bottom=-(m.w+20.0)
	toast_panel.offset_top=toast_panel.offset_bottom-TOAST_SIZE.y
