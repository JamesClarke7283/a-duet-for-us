class_name DuetExportCredits
extends SceneTree

func _initialize() -> void:
	var file := FileAccess.open("res://licenses/Godot-third-party.txt",FileAccess.WRITE)
	file.store_string("Third-party components included in Godot Engine\n\n")
	for component in Engine.get_copyright_info():
		file.store_string(str(component) + "\n\n")
	for name in Engine.get_license_info():
		file.store_string(str(name) + "\n" + str(Engine.get_license_info()[name]) + "\n\n")
	quit()
