class_name LoveStage
extends Control

var james: Texture2D
var dominica: Texture2D
var font: Font
var love: float = 0.0
var shown_love: float = 0.0
var active_character: int = 0
var time: float = 0.0
var hearts: Array[Dictionary] = []
const ROSE = Color("#f3a2bd")
const MINT = Color("#9bdccf")

func _ready() -> void:
	james = load("res://assets/characters/james.png")
	dominica = load("res://assets/characters/dominica.png")
	font = load("res://assets/fonts/body.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	time += delta
	shown_love = move_toward(shown_love, love, delta * 0.32)
	for heart in hearts:
		heart.age += delta
		heart.pos += heart.velocity * delta
	for i in range(hearts.size() - 1, -1, -1):
		if hearts[i].age >= hearts[i].life:
			hearts.remove_at(i)
	queue_redraw()

func centers() -> Vector2:
	return Vector2(240 + shown_love * 120, size.x - 240 - shown_love * 120)

func celebrate(who: int, big: bool = false) -> void:
	var x: float = centers()[who]
	for i in range(12 if big else 5):
		hearts.append({"pos":Vector2(x + randf_range(-75,75), randf_range(100,210)), "velocity":Vector2(randf_range(-25,25),randf_range(-62,-32)), "age":0.0,"life":randf_range(1.6,3.0),"scale":randf_range(2,4),"color":ROSE if who == 0 else MINT})

func _box(rect: Rect2, color: Color, radius: int = 15) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	draw_style_box(box, rect)

func _draw() -> void:
	var w := size.x
	_box(Rect2(Vector2.ZERO, size), Color("#1c1a30"), 20)
	# The arched garden windows, moon and tiny stars are drawn as game art.
	for center_x in [138.0, w / 2, w - 138]:
		draw_rect(Rect2(center_x - 94, 104, 188, 180), Color("#25233c"))
		draw_arc(Vector2(center_x, 104), 94, PI, TAU, 48, Color("#3e3656"), 2, true)
		draw_line(Vector2(center_x - 94,104), Vector2(center_x - 94,283), Color("#3e3656"), 2)
		draw_line(Vector2(center_x + 94,104), Vector2(center_x + 94,283), Color("#3e3656"), 2)
		draw_line(Vector2(center_x,14), Vector2(center_x,283), Color("#38324d"), 2)
		draw_line(Vector2(center_x - 93,126), Vector2(center_x + 93,126), Color("#38324d"), 2)
	draw_circle(Vector2(w - 124, 57), 19, Color("#e6d3af"))
	draw_circle(Vector2(w - 116, 51), 18, Color("#1c1a30"))
	for i in range(28):
		var p := Vector2(32 + fmod(float(i * 137), w - 64), 22 + fmod(float(i * 73), 182))
		var a := 0.3 + sin(time * 0.8 + i) * 0.16
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0.9,0.8,0.7,a))
	draw_rect(Rect2(0,282,w,size.y - 282),Color("#242038"))
	draw_line(Vector2(0,283),Vector2(w,283),Color("#504057"),2)
	for x in range(30, int(w), 80):
		draw_line(Vector2(x,284),Vector2(x-50,size.y),Color("#312940"),1)
	# Small flowering plants at the sides frame the stage.
	for side in [35.0, w - 35.0]:
		for i in range(5):
			var base := Vector2(side + (i-2)*11,281)
			var tip := base + Vector2((i-2)*9,-38-abs(i-2)*9)
			draw_line(base,tip,Color("#49796f"),3)
			draw_rect(Rect2(tip-Vector2(4,3),Vector2(8,6)),ROSE.darkened(0.25))
	if james == null or dominica == null:
		return
	var xs := centers()
	for who in range(2):
		var tint: Color = ROSE if who == 0 else MINT
		_draw_shadow(Vector2(xs[who],287),Vector2(91,10),Color(tint,0.12 if who == active_character else 0.05))
		var height: float = 264 if who == 0 else 236
		var texture: Texture2D = james if who == 0 else dominica
		var width: float = height * texture.get_width() / float(texture.get_height())
		var dy := sin(time * 1.6 + who) * 0.65
		var rect := Rect2(xs[who]-width/2, 282-height+dy, width,height)
		draw_texture_rect(texture,rect,false,Color.WHITE if who == active_character else Color(0.8,0.8,0.86))
		var caption := "JAMES" if who == 0 else "DOMINICA"
		var text_width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		draw_string(font,Vector2(xs[who]-text_width/2,310),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,tint)
	for heart in hearts:
		var c: Color = heart.color
		c.a = minf(1.0,(heart.life-heart.age)*1.4)
		draw_heart(heart.pos,heart.scale,c)
	if shown_love > 0.5:
		draw_heart(Vector2(w/2,60 + sin(time)*3),4.0,Color(ROSE,shown_love*0.8))

func _draw_shadow(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle := TAU * i / 32.0
		points.append(center + Vector2(cos(angle)*radius.x,sin(angle)*radius.y))
	draw_colored_polygon(points,color)

func draw_heart(pos: Vector2, pixel: float, color: Color) -> void:
	var rows = ["0110110","1111111","1111111","0111110","0011100","0001000"]
	for y in range(rows.size()):
		for x in range(7):
			if rows[y][x] == "1":
				draw_rect(Rect2(pos + Vector2(x-3,y-3)*pixel,Vector2(pixel,pixel)),color)
