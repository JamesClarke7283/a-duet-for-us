class_name DuetPiano
extends Control

signal note_played(note: int)
const NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B", "C"]
const KEY_NAMES = ["A", "W", "S", "E", "D", "F", "T", "G", "Y", "H", "U", "J", "K"]
const KEY_CODES = [KEY_A, KEY_W, KEY_S, KEY_E, KEY_D, KEY_F, KEY_T, KEY_G, KEY_Y, KEY_H, KEY_U, KEY_J, KEY_K]
const WHITE = [0, 2, 4, 5, 7, 9, 11, 12]
const BLACK = [1, 3, 6, 8, 10]
const BLACK_AFTER = [0, 1, 3, 4, 5]
var expected_note: int = -1
var accent := Color("#f3a2bd")
var enabled: bool = false
var pulses: Dictionary = {}
var font: Font

func _ready() -> void:
	font = load("res://assets/fonts/mono.ttf")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	for note in pulses.keys():
		pulses[note] -= delta
		if pulses[note] <= 0.0:
			pulses.erase(note)
	queue_redraw()

func key_rect(note: int) -> Rect2:
	var width := size.x / 8.0
	if note in WHITE:
		return Rect2(WHITE.find(note) * width + 2, 2, width - 4, size.y - 4)
	var slot: int = BLACK_AFTER[BLACK.find(note)]
	return Rect2((slot + 1) * width - width * 0.30, 0, width * 0.60, size.y * 0.61)

func _draw() -> void:
	if font == null:
		return
	for note in WHITE:
		_draw_key(note, false)
	for note in BLACK:
		_draw_key(note, true)

func _draw_key(note: int, black: bool) -> void:
	var rect := key_rect(note)
	var col := Color("#302e40") if black else Color("#f7edde")
	var down: bool = pulses.has(note)
	if down:
		col = accent if not black else accent.darkened(0.25)
	elif note == expected_note and enabled:
		col = Color("#b8dfd6") if accent.g > accent.r else Color("#f5c5d4")
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.border_width_bottom = 5
	style.border_color = Color("#11121d") if black else Color("#a99fac")
	draw_style_box(style, rect)
	if note == expected_note and enabled:
		draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 5)), accent, true)
	var ink := Color("#eae2e9") if black else Color("#393344")
	var center := rect.get_center().x
	var y := rect.end.y - 43
	var name_text: String = NOTE_NAMES[note] + ("5" if note == 12 else "4")
	draw_string(font, Vector2(center - font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x / 2, y), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ink)
	var key_text: String = KEY_NAMES[note]
	draw_string(font, Vector2(center - 5, y + 27), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink.lightened(0.22) if black else ink.lightened(0.3))

func flash(note: int) -> void:
	pulses[note] = 0.28
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos: Vector2 = event.position
		for note in BLACK:
			if key_rect(note).has_point(pos):
				note_played.emit(note)
				accept_event()
				return
		for note in WHITE:
			if key_rect(note).has_point(pos):
				note_played.emit(note)
				accept_event()
				return

func _unhandled_key_input(event: InputEvent) -> void:
	if not enabled or not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode
	if code in KEY_CODES:
		note_played.emit(KEY_CODES.find(code))
		get_viewport().set_input_as_handled()
