class_name SettingsMenu
extends CanvasLayer

signal performance_mode_changed(mode: String)
signal menu_opened
signal menu_closed

@onready var panel: Panel = $Panel
@onready var mode_label: Label = $Panel/Mode
@onready var battery_button: Button = $Panel/Battery30
@onready var smooth_button: Button = $Panel/Smooth60
@onready var close_button: Button = $Panel/Close

var current_mode := "smooth60"
var blocker:ColorRect

func _ready() -> void:
	blocker=ColorRect.new()
	blocker.name="ModalBlocker"
	blocker.color=Color(0,0,0,0.45)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(blocker)
	move_child(blocker,0)
	blocker.visible=false
	panel.visible = false
	battery_button.pressed.connect(func(): _choose("battery30"))
	smooth_button.pressed.connect(func(): _choose("smooth60"))
	close_button.pressed.connect(close)
	_refresh()

func open(mode: String) -> void:
	if panel.visible:
		return
	current_mode = mode
	_refresh()
	blocker.visible=true
	panel.visible = true
	menu_opened.emit()

func close() -> void:
	if not panel.visible:
		return
	panel.visible = false
	blocker.visible=false
	menu_closed.emit()

func _choose(mode: String) -> void:
	current_mode = mode
	_refresh()
	performance_mode_changed.emit(mode)

func _refresh() -> void:
	mode_label.text = "PERFORMANCE: 30 FPS / BATTERY" if current_mode == "battery30" else "PERFORMANCE: 60 FPS / SMOOTH"
	battery_button.disabled = current_mode == "battery30"
	smooth_button.disabled = current_mode == "smooth60"
