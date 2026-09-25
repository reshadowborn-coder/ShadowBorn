class_name IPhoneUILayout
extends Node

const COMBAT_WIDTH:=536.0
const ROOM5_WIDTH:=700.0
const TOAST_SIZE:=Vector2(1040,90)
const FALLBACK_TOUCH:=80.0

@onready var combat_panel:Control=get_parent().get_node("CombatHUD/Panel")
@onready var combat_a1:Button=get_parent().get_node("CombatHUD/Panel/A1")
@onready var combat_a2:Button=get_parent().get_node("CombatHUD/Panel/A2")
@onready var settings_button:Button=get_parent().get_node("CombatHUD/SettingsButton")
@onready var room5_panel:Control=get_parent().get_node("MultiTargetHUD/Panel")
@onready var room5_target_a:Button=get_parent().get_node("MultiTargetHUD/Panel/TargetA")
@onready var room5_target_b:Button=get_parent().get_node("MultiTargetHUD/Panel/TargetB")
@onready var room5_a1:Button=get_parent().get_node("MultiTargetHUD/Panel/A1")
@onready var room5_a2:Button=get_parent().get_node("MultiTargetHUD/Panel/A2")
@onready var toast_panel:Control=get_parent().get_node("StoryToast/Panel")

func _ready()->void:
	get_viewport().size_changed.connect(apply_safe_area)
	call_deferred("apply_safe_area")

func apply_safe_area()->void:
	var m:=MobileSafeArea.current(get_viewport())
	var touch:=MobileSafeArea.minimum_touch_target(get_viewport(),44.0,FALLBACK_TOUCH)

	combat_a1.size.y=touch
	combat_a2.size.y=touch
	combat_a1.custom_minimum_size.y=touch
	combat_a2.custom_minimum_size.y=touch
	var combat_height:=110.0+touch+26.0
	combat_panel.offset_right=-m.z
	combat_panel.offset_left=combat_panel.offset_right-COMBAT_WIDTH
	combat_panel.offset_bottom=-m.w
	combat_panel.offset_top=combat_panel.offset_bottom-combat_height

	settings_button.custom_minimum_size.y=touch
	settings_button.offset_right=-m.z
	settings_button.offset_left=settings_button.offset_right-196.0
	settings_button.offset_top=m.y
	settings_button.offset_bottom=settings_button.offset_top+touch

	room5_target_a.size.y=touch
	room5_target_b.size.y=touch
	room5_target_a.custom_minimum_size.y=touch
	room5_target_b.custom_minimum_size.y=touch
	var action_y:=48.0+touch+16.0
	room5_a1.position.y=action_y
	room5_a2.position.y=action_y
	room5_a1.size.y=touch
	room5_a2.size.y=touch
	room5_a1.custom_minimum_size.y=touch
	room5_a2.custom_minimum_size.y=touch
	var room5_height:=action_y+touch+26.0
	room5_panel.offset_left=-ROOM5_WIDTH*0.5
	room5_panel.offset_right=ROOM5_WIDTH*0.5
	room5_panel.offset_bottom=-m.w
	room5_panel.offset_top=room5_panel.offset_bottom-room5_height

	toast_panel.offset_left=-TOAST_SIZE.x*0.5
	toast_panel.offset_right=TOAST_SIZE.x*0.5
	toast_panel.offset_bottom=-(m.w+20.0)
	toast_panel.offset_top=toast_panel.offset_bottom-TOAST_SIZE.y
