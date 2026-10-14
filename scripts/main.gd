class_name DuetGame
extends Control

const ROSE := Color("#f3a2bd")
const MINT := Color("#9bdccf")
const INK := Color("#f7edde")
const MUTED := Color("#a69bac")
const PANEL := Color("#262136")
@export var save_path: String = "user://duet_progress.json"
@export var settings_path: String = "user://settings.cfg"
const TOTAL_NOTES := 64
const AUDIO_NAMES := ["C4","Cs4","D4","Ds4","E4","F4","Fs4","G4","Gs4","A4","As4","B4","C5"]
const SONGS := [
	{"title":"First notes", "subtitle":"A little courage. A first hello.", "story":"An empty piano. Two curious hearts.\nJames plays the first note. Dominica answers.\nA conversation begins, one key at a time.", "end":"James: I was hoping you would play along.\nDominica: I was hoping you would ask.", "melody":[0,4,7,4,2,5,9,5,4,7,12,7,5,4,2,0]},
	{"title":"Finding our rhythm", "subtitle":"Your note. My answer. Our rhythm.", "story":"One note became a conversation.\nNow neither of you wants the song to end.\nYou are learning the sound of each other.", "end":"Dominica: It sounds different with you.\nJames: Better?\nDominica: Like somewhere I want to stay.", "melody":[0,2,4,7,9,7,4,2,5,9,12,9,7,5,4,2,0,4,7,9,7,4,2,0]},
	{"title":"Our song", "subtitle":"Some things are easier to say with music.", "story":"The room feels warmer. The distance feels smaller.\nThere is one more melody to share.\nLet your hearts finish the sentence.", "end":"James: I think this is my favourite song.\nDominica: Mine too.\nTogether: Because it is ours.", "melody":[4,7,9,12,11,9,7,4,5,9,7,5,4,2,0,2,4,7,12,9,7,4,2,0]}
]

@export var song_index: int = 0
@export var note_index: int = 0
@export var total_hits: int = 0
@export var streak: int = 0
@export var mistakes: int = 0
@export var story_complete: bool = false
var best_streak: int = 0
var mode: String = "menu"
var paused: bool = false
var previewing: bool = false
var preview_token: int = 0
var free_turn: int = 0
var free_hearts: int = 0
var muted: bool = false
var volume: float = 0.65
var preview_interval: float = 0.55
var title_font: Font
var body_font: Font
var mono_font: Font
var stage
var piano
var turn_label: Label
var note_label: Label
var key_label: Label
var status_label: Label
var chapter_label: Label
var subtitle_label: Label
var love_label: Label
var streak_label: Label
var progress_bar: ProgressBar
var cue_panel: Panel
var sequence: Control
var overlay: Control
var listen_button: Button
var pause_button: Button
var sound_button: Button
var audio_streams: Array[AudioStream] = []
var players: Array[AudioStreamPlayer] = []
var voice: int = 0
var chord_clock: int = 0
var theme_player: AudioStreamPlayer
var theme_button: Button
var theme_enabled: bool = true
var theme_fade: Tween
var theme_volume_target: float = 999.0

func _ready() -> void:
	title_font = load("res://assets/fonts/title.ttf")
	body_font = load("res://assets/fonts/body.ttf")
	mono_font = load("res://assets/fonts/mono.ttf")
	for audio_name in AUDIO_NAMES:
		audio_streams.append(load("res://assets/audio/" + audio_name + ".wav"))
	for i in range(20):
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	_load_progress()
	_setup_theme_audio()
	_build_ui()
	_apply_volume()
	show_menu()
	print("DUET_READY: 3 songs, 64 alternating notes, 13 playable piano keys")

func _setup_theme_audio() -> void:
	theme_player = AudioStreamPlayer.new()
	theme_player.name = "ThemeMusic"
	var stream: AudioStreamOggVorbis = load("res://assets/audio/theme.ogg")
	stream.loop = true
	theme_player.stream = stream
	theme_player.volume_db = -8.0
	add_child(theme_player)
	theme_player.play()
	_update_theme_audio()

func _update_theme_audio() -> void:
	if not is_instance_valid(theme_player):
		return
	theme_player.stream_paused = paused or not theme_enabled
	var target: float = -28.0 if previewing else (-20.0 if mode in ["story", "free"] and overlay == null else -8.0)
	if not is_equal_approx(target, theme_volume_target):
		theme_volume_target = target
		if is_instance_valid(theme_fade):
			theme_fade.kill()
		theme_fade = create_tween()
		theme_fade.tween_property(theme_player, "volume_db", target, 0.4)
	if is_instance_valid(theme_button):
		theme_button.text = "Music on" if theme_enabled else "Music off"

func toggle_theme() -> void:
	theme_enabled = not theme_enabled
	_update_theme_audio()
	_save_preferences()

func _style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	return box

func _panel(rect: Rect2, color: Color = PANEL, parent: Node = null) -> Panel:
	var item := Panel.new()
	item.position = rect.position
	item.size = rect.size
	item.add_theme_stylebox_override("panel",_style(color,Color("#44364c")))
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(item)
	return item

func _label(text_value: String, rect: Rect2, font_size: int = 18, color: Color = INK, parent: Node = null, font: Font = null) -> Label:
	var item := Label.new()
	item.text = text_value
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_override("font",font if font != null else body_font)
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(item)
	return item

func _button(text_value: String, rect: Rect2, callback: Callable, parent: Node = null, primary: bool = false) -> Button:
	var item := Button.new()
	item.text = text_value
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_override("font",body_font)
	item.add_theme_font_size_override("font_size",16)
	item.add_theme_color_override("font_color",Color("#211827") if primary else INK)
	item.add_theme_color_override("font_hover_color",Color("#211827") if primary else Color.WHITE)
	item.add_theme_color_override("font_focus_color",Color("#211827") if primary else INK)
	item.add_theme_color_override("font_pressed_color",Color("#211827") if primary else INK)
	item.add_theme_stylebox_override("normal",_style(ROSE if primary else PANEL,ROSE if primary else Color("#4f4057")))
	item.add_theme_stylebox_override("hover",_style(ROSE.lightened(0.12) if primary else Color("#3d3049"),ROSE))
	item.add_theme_stylebox_override("pressed",_style(ROSE.darkened(0.10) if primary else Color("#49354e"),ROSE))
	item.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,MINT,12))
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(callback)
	(parent if parent != null else self).add_child(item)
	return item

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#14121f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_label("J  +  D     /     A LITTLE LOVE STORY",Rect2(64,26,650,26),13,ROSE,null,mono_font)
	theme_button = _button("Music on",Rect2(748,27,136,36),toggle_theme)
	_button("Home",Rect2(897,27,82,36),show_menu)
	pause_button = _button("Pause",Rect2(990,27,90,36),toggle_pause)
	sound_button = _button("Sound on",Rect2(1091,27,125,36),toggle_mute)
	_label("A Duet for Us",Rect2(61,68,735,73),61,INK,null,title_font)
	subtitle_label = _label("Two hearts. One piano. A melody you make together.",Rect2(64,145,736,32),18,MUTED)
	chapter_label = _label("YOUR STORY IN THREE SONGS",Rect2(859,91,357,25),12,MINT,null,mono_font)
	love_label = _label("A spark, waiting to happen",Rect2(859,119,357,29),19,INK)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(859,158)
	progress_bar.size = Vector2(357,8)
	progress_bar.show_percentage = false
	progress_bar.max_value = TOTAL_NOTES
	progress_bar.add_theme_stylebox_override("background",_style(Color("#332940"),Color.TRANSPARENT,4))
	progress_bar.add_theme_stylebox_override("fill",_style(ROSE,Color.TRANSPARENT,4))
	add_child(progress_bar)
	stage = load("res://scripts/love_stage.gd").new()
	stage.name = "Stage"
	stage.position = Vector2(64,203)
	stage.size = Vector2(1152,321)
	add_child(stage)
	cue_panel = _panel(Rect2(502,256,276,176),Color("#201b31"))
	turn_label = _label("JAMES, YOUR TURN",Rect2(13,14,250,26),13,ROSE,cue_panel,mono_font)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_label = _label("C4",Rect2(10,39,256,74),58,INK,cue_panel,title_font)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label = _label("Press A  /  click C4",Rect2(10,124,256,30),16,INK,cue_panel)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label = _label("Follow the glowing key. Every note brings you closer.",Rect2(385,446,510,30),14,MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sequence = Control.new()
	sequence.name = "UpcomingNotes"
	sequence.position = Vector2(64,539)
	sequence.size = Vector2(1152,56)
	add_child(sequence)
	_panel(Rect2(64,611,1152,231),Color("#201c2d"))
	_label("THE PIANO",Rect2(85,621,210,28),12,MINT,null,mono_font)
	streak_label = _label("Take your time. This is your song.",Rect2(260,620,540,28),14,MUTED)
	listen_button = _button("Listen first",Rect2(875,621,142,31),toggle_preview)
	_button("How to play",Rect2(1030,621,165,31),show_help)
	piano = load("res://scripts/piano.gd").new()
	piano.name = "Piano"
	piano.position = Vector2(195,664)
	piano.size = Vector2(890,161)
	piano.note_played.connect(play_note)
	add_child(piano)
	_label("JAMES",Rect2(84,698,104,24),12,ROSE,null,mono_font)
	_label("DOMINICA",Rect2(1094,744,114,24),12,MINT,null,mono_font)
	_label("A S D F G H J K  ·  white keys      W E T Y U  ·  black keys",Rect2(64,857,810,25),12,MUTED,null,mono_font)
	_label("ESC  pause     SPACE  listen",Rect2(874,857,342,25),12,MUTED,null,mono_font)
	var theme_credit := _label("THEME: UNDER PRESSURE × A CROWN OF STARS",Rect2(64,884,1152,14),9,MUTED,null,mono_font)
	theme_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null
	paused = false

func _dialog(eyebrow: String, heading: String, body: String, actions: Array) -> void:
	_stop_preview()
	_clear_overlay()
	piano.enabled = false
	overlay = Control.new()
	overlay.name = "Dialog"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.06,0.04,0.10,0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var h: float = 294 + actions.size() * 53
	var panel := _panel(Rect2(370,(900-h)/2,540,h),Color("#262036"),overlay)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var tag := _label(eyebrow,Rect2(30,23,480,29),12,MINT,panel,mono_font)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var heading_label := _label(heading,Rect2(24,58,492,80),39,INK,panel,title_font)
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body_label := _label(body,Rect2(38,145,464,115),17,Color("#cec1d2"),panel)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(actions.size()):
		var action: Dictionary = actions[i]
		var button := _button(action.text,Rect2(68,274+i*53,404,43),action.callback,panel,i==0)
		button.name = "Action" + str(i)
		if i == 0:
			button.grab_focus()
	_update_theme_audio()

func show_menu() -> void:
	_stop_preview()
	if mode == "story":
		_save_progress()
	mode = "menu"
	cue_panel.hide()
	stage.love = float(total_hits) / TOTAL_NOTES
	stage.active_character = 0
	chapter_label.text = "YOUR STORY IN THREE SONGS"
	subtitle_label.text = "Two hearts. One piano. A melody you make together."
	_update_meter()
	var primary_text := "Continue your duet" if total_hits > 0 and not story_complete else "Begin your duet"
	var actions: Array = [{"text":primary_text,"callback":func(): begin_story(story_complete)},{"text":"Free piano · play anything","callback":begin_free_play}]
	if total_hits > 0 and not story_complete:
		actions.append({"text":"Start a new story","callback":confirm_restart})
	_dialog("JAMES  +  DOMINICA","Two hearts. One melody.","Play a note, then pass the moment.\nFollow the keys through three little love songs.\nNo timer. Just the two of you.",actions)
	pause_button.disabled = true
	listen_button.disabled = true
	_refresh_sequence()

func begin_story(reset: bool = false) -> void:
	if reset:
		song_index = 0
		note_index = 0
		total_hits = 0
		streak = 0
		mistakes = 0
		best_streak = 0
		story_complete = false
	mode = "story"
	_clear_overlay()
	pause_button.disabled = false
	listen_button.disabled = false
	cue_panel.show()
	_refresh()
	if note_index == 0:
		_show_intro()
	elif note_index >= SONGS[song_index].melody.size():
		_finish_song()
	_save_progress()

func _show_intro() -> void:
	var song: Dictionary = SONGS[song_index]
	_dialog("CHAPTER " + str(song_index+1) + " OF 3",song.title,song.story,[{"text":"Play together","callback":_start_playing}])

func _start_playing() -> void:
	_clear_overlay()
	_refresh()
	print("DUET_CHAPTER: ",song_index+1," note=",note_index)

func begin_free_play() -> void:
	_stop_preview()
	_clear_overlay()
	mode = "free"
	free_turn = 0
	free_hearts = 0
	cue_panel.show()
	pause_button.disabled = false
	listen_button.disabled = true
	_refresh()

func current_note() -> int:
	if mode != "story" or note_index >= SONGS[song_index].melody.size():
		return -1
	return int(SONGS[song_index].melody[note_index])

func current_character() -> int:
	return free_turn % 2 if mode == "free" else total_hits % 2

func _refresh() -> void:
	var who := current_character()
	var color: Color = ROSE if who == 0 else MINT
	var person := "JAMES" if who == 0 else "DOMINICA"
	piano.enabled = overlay == null and not paused and mode in ["story","free"]
	piano.accent = color
	piano.expected_note = current_note()
	stage.active_character = who
	stage.love = minf(float(free_hearts)/32,1.0) if mode == "free" else float(total_hits)/TOTAL_NOTES
	turn_label.text = person + ", YOUR TURN"
	turn_label.add_theme_color_override("font_color",color)
	if mode == "free":
		note_label.text = "Any note"
		note_label.add_theme_font_size_override("font_size",40)
		key_label.text = "Make a little music together"
		chapter_label.text = "FREE PIANO  /  NO RULES"
		subtitle_label.text = "Play anything. Take turns. See where the melody goes."
		status_label.text = "Every key is a good beginning."
	else:
		note_label.add_theme_font_size_override("font_size",58)
		var note := current_note()
		note_label.text = _note_name(note) if note >= 0 else "Lovely"
		key_label.text = ("Press " + str(piano.KEY_NAMES[note]) + "  /  click " + _note_name(note)) if note >= 0 else "A song, shared."
		chapter_label.text = "CHAPTER %d / 3   ·   %s" % [song_index+1,str(SONGS[song_index].title).to_upper()]
		subtitle_label.text = SONGS[song_index].subtitle
		status_label.text = "Follow the glowing key. Every note brings you closer."
	streak_label.text = ("%d notes shared  ·  %d in harmony" % [total_hits,streak]) if mode == "story" else ("%d notes, just for you two" % free_hearts)
	_update_meter()
	_refresh_sequence()
	_update_theme_audio()

func _update_meter() -> void:
	var amount: int = mini(free_hearts*2,TOTAL_NOTES) if mode == "free" else total_hits
	progress_bar.value = amount
	if amount >= TOTAL_NOTES:
		love_label.text = "In love, in harmony"
	elif amount >= 40:
		love_label.text = "A melody becoming love"
	elif amount >= 16:
		love_label.text = "Finding each other"
	elif amount > 0:
		love_label.text = "A spark between you"
	else:
		love_label.text = "A spark, waiting to happen"

func _note_name(note: int) -> String:
	return str(DuetPiano.NOTE_NAMES[note]) + ("5" if note == 12 else "4")

func _refresh_sequence() -> void:
	for child in sequence.get_children():
		sequence.remove_child(child)
		child.queue_free()
	var title := "UP NEXT" if mode == "story" else "TAKE TURNS"
	_label(title,Rect2(0,4,145,26),12,MUTED,sequence,mono_font)
	var description := ("%d / %d notes" % [mini(note_index+1,SONGS[song_index].melody.size()),SONGS[song_index].melody.size()]) if mode == "story" else "James + Dominica"
	_label(description,Rect2(0,29,148,21),12,MUTED,sequence)
	if mode != "story":
		_label("A little courage. A little music. A lot of heart.",Rect2(191,0,810,56),20,INK,sequence,title_font)
		return
	for i in range(9):
		var index := note_index+i
		if index >= SONGS[song_index].melody.size():
			break
		var who := (total_hits+i) % 2
		var color: Color = ROSE if who == 0 else MINT
		var panel := _panel(Rect2(181+i*108,0,99,54),color.darkened(0.76) if i == 0 else Color("#211c2c"),sequence)
		var note_text := _note_name(int(SONGS[song_index].melody[index]))
		var l := _label(note_text,Rect2(4,3,91,28),20,color if i == 0 else MUTED,panel,mono_font)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l = _label("JAMES" if who == 0 else "DOMINICA",Rect2(4,31,91,17),9,color,panel,mono_font)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func play_note(note: int) -> void:
	if note < 0 or note >= 13 or overlay != null or paused or mode not in ["story","free"]:
		return
	if previewing:
		_stop_preview()
	_play_sound(note)
	piano.flash(note)
	if mode == "free":
		stage.celebrate(free_turn%2)
		free_turn += 1
		free_hearts += 1
		_refresh()
		return
	if note != current_note():
		mistakes += 1
		streak = 0
		status_label.text = "Try " + _note_name(current_note()) + " · no rush, you have each other."
		streak_label.text = "A little detour. Keep playing together."
		print("DUET_RETRY: expected=",current_note()," played=",note)
		return
	var who := current_character()
	total_hits += 1
	note_index += 1
	streak += 1
	best_streak = maxi(best_streak,streak)
	stage.celebrate(who,streak%8==0)
	if note_index%4 == 0:
		_play_chord()
	print("DUET_NOTE: hits=",total_hits," next=",("James" if total_hits%2==0 else "Dominica")," love=",total_hits,"/64")
	_save_progress()
	_refresh()
	status_label.text = ("James" if who==0 else "Dominica") + ": a little closer."
	if note_index >= SONGS[song_index].melody.size():
		_finish_song()

func _play_sound(note: int, decibels: float = -7.0, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = players[voice%players.size()]
	voice += 1
	player.stream = audio_streams[note]
	player.volume_db = decibels
	player.pitch_scale = pitch
	player.play()

func _play_chord() -> void:
	var chords: Array = [[0,4,7],[5,9,0],[7,11,2],[0,4,7]]
	for note in chords[chord_clock%4]:
		_play_sound(int(note),-28.0,0.5)
	chord_clock += 1

func _finish_song() -> void:
	piano.enabled = false
	if song_index == SONGS.size()-1:
		story_complete = true
		_save_progress()
		show_finale()
		return
	_dialog("A LITTLE CLOSER",SONGS[song_index].title + " · complete",SONGS[song_index].end,[{"text":"The next chapter","callback":next_chapter},{"text":"Back to the piano room","callback":show_menu}])
	print("DUET_SONG_COMPLETE: ",song_index+1)

func next_chapter() -> void:
	song_index += 1
	note_index = 0
	chord_clock = 0
	_save_progress()
	_refresh()
	_show_intro()

func show_finale() -> void:
	stage.love = 1.0
	stage.celebrate(0,true)
	stage.celebrate(1,true)
	cue_panel.hide()
	_update_meter()
	var body := "James: I think this is my favourite song.\nDominica: Mine too. Because it is ours.\n\n64 notes. Two hearts. One beautiful beginning."
	_dialog("YOUR LOVE STORY, IN HARMONY","And so, they fell in love.",body,[{"text":"Keep making music · free piano","callback":begin_free_play},{"text":"Play the story again","callback":func(): begin_story(true)},{"text":"Back to the piano room","callback":show_menu}])
	print("DUET_FINALE: story complete; best_streak=",best_streak," retries=",mistakes)

func toggle_preview() -> void:
	if mode != "story" or overlay != null:
		return
	if previewing:
		_stop_preview()
		return
	previewing = true
	_update_theme_audio()
	preview_token += 1
	var token := preview_token
	listen_button.text = "Stop listening"
	status_label.text = "Listen to the melody. Join in whenever you like."
	var melody: Array = SONGS[song_index].melody
	for i in range(note_index,melody.size()):
		if token != preview_token or not previewing or overlay != null:
			return
		var note: int = melody[i]
		_play_sound(note,-10)
		piano.flash(note)
		stage.active_character = i%2
		turn_label.text = "LISTEN · " + ("JAMES" if i%2==0 else "DOMINICA")
		note_label.text = _note_name(note)
		key_label.text = "Your progress stays right here"
		await get_tree().create_timer(preview_interval).timeout
	if token == preview_token:
		_stop_preview()

func _stop_preview() -> void:
	previewing = false
	preview_token += 1
	if is_instance_valid(listen_button):
		listen_button.text = "Listen first"
	if is_instance_valid(piano) and mode in ["story","free"]:
		_refresh()

func toggle_pause() -> void:
	if mode not in ["story","free"]:
		return
	if paused:
		_clear_overlay()
		_refresh()
		return
	if overlay != null:
		return
	var actions: Array = [{"text":"Keep playing","callback":func(): _clear_overlay(); _refresh()}]
	if mode == "story":
		actions.append({"text":"Restart this song","callback":confirm_restart_song})
	actions.append({"text":"Back to the piano room","callback":show_menu})
	_dialog("TAKE A BREATH","The music can wait.","Your place is saved. Come back whenever you are ready.\n\nTip: SPACE previews the melody.\nClick any piano key, or use the letters beneath it.",actions)
	paused = true
	_update_theme_audio()

func show_help() -> void:
	var was_menu := mode == "menu"
	_dialog("HOW TO PLAY","One note. Then the other.","James plays the pink turns. Dominica plays the mint turns.\nPress the letter shown, or click the glowing piano key.\nWhite keys: A S D F G H J K · Black keys: W E T Y U\n\nRight notes grow your love. There is no time limit.",[{"text":"Got it","callback":show_menu if was_menu else func(): _clear_overlay(); _refresh()}])

func confirm_restart() -> void:
	_dialog("A NEW BEGINNING","Start your story again?","This resets your saved song progress.\nYou can always make a new favourite memory.",[{"text":"Start a new story","callback":func(): begin_story(true)},{"text":"Keep our progress","callback":show_menu}])

func confirm_restart_song() -> void:
	_dialog("ONE MORE TIME","Restart this song?","Return to the first note of this chapter.\nYour earlier chapters will stay complete.",[{"text":"Restart song","callback":restart_song},{"text":"Keep playing","callback":func(): _clear_overlay(); _refresh()}])

func restart_song() -> void:
	note_index = 0
	total_hits = 0
	for i in range(song_index):
		total_hits += SONGS[i].melody.size()
	streak = 0
	story_complete = false
	_save_progress()
	_start_playing()

func toggle_mute() -> void:
	muted = not muted
	_apply_volume()
	_save_preferences()

func _apply_volume() -> void:
	AudioServer.set_bus_mute(0,muted)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.001)))
	if is_instance_valid(sound_button):
		sound_button.text = "Sound off" if muted else "Sound on"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_SPACE and overlay == null:
		toggle_preview()
		get_viewport().set_input_as_handled()

func _save_progress() -> void:
	var data := {"version":1,"song":song_index,"note":note_index,"total":total_hits,"best":best_streak,"mistakes":mistakes,"complete":story_complete}
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func _load_progress() -> void:
	if FileAccess.file_exists(save_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Dictionary and int(data.get("version",0)) == 1:
			song_index = clampi(int(data.get("song",0)),0,2)
			note_index = clampi(int(data.get("note",0)),0,SONGS[song_index].melody.size())
			total_hits = note_index
			for i in range(song_index):
				total_hits += SONGS[i].melody.size()
			best_streak = maxi(0,int(data.get("best",0)))
			mistakes = maxi(0,int(data.get("mistakes",0)))
			story_complete = total_hits == TOTAL_NOTES
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		muted = bool(config.get_value("audio","muted",false))
		theme_enabled = bool(config.get_value("audio","theme_enabled",true))
		volume = clampf(float(config.get_value("audio","volume",0.65)),0.0,1.0)

func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("audio","muted",muted)
	config.set_value("audio","theme_enabled",theme_enabled)
	config.set_value("audio","volume",volume)
	config.save(settings_path)


func _exit_tree() -> void:
	if is_instance_valid(theme_fade):
		theme_fade.kill()
	if is_instance_valid(theme_player):
		theme_player.stop()
		theme_player.stream = null
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	players.clear()
	audio_streams.clear()

func get_test_state() -> Dictionary:
	return {"mode":mode,"song":song_index,"note":note_index,"total":total_hits,"expected":current_note(),"character":current_character(),"paused":paused,"dialog":overlay!=null,"complete":story_complete,"hearts":stage.hearts.size(),"muted":muted,"previewing":previewing,"free_turn":free_turn}
