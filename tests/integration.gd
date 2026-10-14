class_name DuetIntegrationTests
extends SceneTree

var game
var failures: Array[String] = []
var checks: int = 0
const TEST_SAVE = "user://duet_test_progress.json"
const TEST_SETTINGS = "user://duet_test_settings.cfg"

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		print("FAIL: ",description)

func key(code: int, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	var release := InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	release.pressed = false
	root.push_input(release)

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.settings_path = TEST_SETTINGS
	root.add_child(game)
	await process_frame
	check(game.mode == "menu" and game.overlay != null,"Title menu is shown")
	check(game.stage.james != null and game.stage.dominica != null,"Both supplied sprites load")
	check(game.audio_streams.size()==13,"All 13 piano samples load")
	check(game.theme_player.playing,"Theme starts automatically")
	check(game.theme_player.stream.loop,"Theme resource loops")
	check(game.theme_player.stream.get_length()>240,"Full requested mashup is loaded")
	await create_timer(0.45).timeout
	check(is_equal_approx(game.theme_player.volume_db,-8.0),"Menu theme reaches background volume")
	game.toggle_theme()
	check(game.theme_player.stream_paused,"Music toggle pauses just the theme")
	check(not AudioServer.is_bus_mute(0),"Music toggle leaves piano audio enabled")
	var position: float = game.theme_player.get_playback_position()
	await create_timer(0.12).timeout
	check(absf(game.theme_player.get_playback_position()-position)<0.08,"Disabled theme holds its playback position")
	game.toggle_theme()
	check(not game.theme_player.stream_paused,"Music toggle resumes theme")
	game.theme_player.seek(game.theme_player.stream.get_length()-0.1)
	await create_timer(0.35).timeout
	check(game.theme_player.playing and game.theme_player.get_playback_position()<2.0,"Theme loops at the end of the full recording")
	game.begin_story(true)
	check(game.overlay != null,"Chapter introduction shown")
	game._start_playing()
	check(game.piano.enabled and game.current_note()==0,"First note C4 is ready")
	await create_timer(0.45).timeout
	check(game.theme_player.volume_db < -19.0,"Theme is quieter during piano play")
	key(KEY_S)
	await process_frame
	check(game.total_hits==0 and game.mistakes==1,"Wrong key does not advance or reduce love")
	key(KEY_A)
	await process_frame
	check(game.total_hits==1 and game.current_character()==1,"Keyboard C4 advances to Dominica")
	check(game.current_note()==4 and game.piano.expected_note==4,"E4 is the highlighted next note")
	check(game.stage.hearts.size()>0,"Correct note spawns love hearts")
	check(game.players.any(func(p): return p.playing),"Piano audio is playing")
	key(KEY_D,true)
	await process_frame
	check(game.total_hits==1,"Repeated keyboard events do not auto-complete notes")
	key(KEY_ESCAPE)
	await process_frame
	check(game.paused and not game.piano.enabled,"Escape pauses input")
	check(game.theme_player.stream_paused,"Game pause also pauses theme")
	game.play_note(4)
	check(game.total_hits==1,"Notes cannot progress while paused")
	key(KEY_ESCAPE)
	await process_frame
	check(not game.paused and game.piano.enabled,"Escape resumes")
	check(not game.theme_player.stream_paused,"Resuming the game resumes the same theme")
	game.show_help()
	check(game.overlay!=null and not game.piano.enabled,"Help blocks piano input")
	game._clear_overlay()
	game._refresh()
	game.toggle_preview()
	await create_timer(0.45).timeout
	check(game.theme_player.volume_db < -27.0,"Theme ducks further under the melody preview")
	check(game.previewing and game.total_hits==1,"Preview plays without changing progress")
	game.toggle_preview()
	check(not game.previewing and game.current_note()==4,"Preview stops and restores the current prompt")
	# Exercise mouse hit-testing on a black key in free mode.
	game.begin_free_play()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.piano.key_rect(1).get_center()
	game.piano._gui_input(click)
	check(game.free_turn==1,"Black piano key can be clicked")
	game.begin_story(false)
	game._start_playing()
	var restored = load("res://scenes/main.tscn").instantiate()
	restored.save_path = TEST_SAVE
	restored.settings_path = TEST_SETTINGS
	root.add_child(restored)
	await process_frame
	check(restored.total_hits==1 and restored.note_index==1,"Progress reloads from disk")
	restored.queue_free()
	await process_frame
	for chapter in range(3):
		check(game.song_index==chapter,"Correct chapter index "+str(chapter))
		while game.note_index < game.SONGS[chapter].melody.size():
			var who: int = game.current_character()
			var old_hits: int = game.total_hits
			game.play_note(game.current_note())
			check(game.total_hits==old_hits+1,"Correct note advances exactly once")
			check(game.current_character()!=who,"James and Dominica alternate on every note")
		check(game.overlay!=null,"Chapter ends with a story card")
		if chapter<2:
			game.next_chapter()
			check(game.note_index==0 and game.overlay!=null,"Next chapter starts with introduction")
			game._start_playing()
	check(game.total_hits==64 and game.story_complete,"All 64 notes reach the love-story finale")
	check(is_equal_approx(game.stage.love,1.0),"Love meter reaches 100 percent")
	check(not game.piano.enabled,"Finale prevents extra scoring")
	check(game.best_streak==64,"Streak tracks the completed duet")
	game.begin_free_play()
	for i in range(33):
		game.play_note(i%13)
	check(game.free_turn==33 and game.free_hearts==33,"Free piano accepts every note and alternates")
	check(game.total_hits==64,"Free piano preserves story progress")
	game.toggle_pause()
	check(game.paused,"Free piano can be paused")
	game.toggle_pause()
	check(not game.paused,"Free piano resumes")
	game.toggle_mute()
	check(game.muted and AudioServer.is_bus_mute(0),"Sound toggle mutes the audio bus")
	game.toggle_mute()
	check(not game.muted,"Sound can be restored")
	game.begin_story(true)
	game._start_playing()
	for i in range(16):
		game.play_note(game.current_note())
	game.next_chapter()
	game._start_playing()
	for i in range(3):
		game.play_note(game.current_note())
	game.restart_song()
	check(game.total_hits==16 and game.note_index==0,"Restart song keeps previous chapters")
	game.begin_story(true)
	check(game.total_hits==0 and not game.story_complete,"Story replay resets progress")
	var report := "%d checks, %d failures\n" % [checks,failures.size()]
	for failure in failures:
		report += "FAIL: "+failure+"\n"
	print("DUET_TEST_RESULT: ",report)
	var output := FileAccess.open("res://output/qa/test-report.txt",FileAccess.WRITE)
	output.store_string(report)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	await create_timer(0.7).timeout
	game.queue_free()
	game = null
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
