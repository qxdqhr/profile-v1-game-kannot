extends Node2D
## Stage-C: difficulty, pause, high score, menu.

const LANES := 4
const HIT_Y := 540.0
const PERFECT := 28.0
const GOOD := 55.0
const DIFFS: Array[Dictionary] = [
	{"id": "easy", "name": "简单", "speed": 220.0, "spawn_min": 0.55, "spawn_max": 1.1, "len": 40.0},
	{"id": "normal", "name": "普通", "speed": 280.0, "spawn_min": 0.35, "spawn_max": 0.85, "len": 45.0},
	{"id": "hard", "name": "困难", "speed": 360.0, "spawn_min": 0.22, "spawn_max": 0.55, "len": 50.0},
]

@onready var _hud: Label = $UI/HUD
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _retry: Button = $UI/Overlay/VBox/Retry
@onready var _notes_root: Node2D = $Notes
@onready var _hit_line: ColorRect = $HitLine

var _lane_xs: Array[float] = []
var _score: int = 0
var _combo: int = 0
var _elapsed: float = 0.0
var _spawn_cd: float = 0.0
var _alive: bool = false
var _paused: bool = false
var _in_menu: bool = true
var _note_speed: float = 280.0
var _spawn_min: float = 0.35
var _spawn_max: float = 0.85
var _song_len: float = 45.0
var _rng := RandomNumberGenerator.new()
var _lane_btns: Array[Button] = []
var _menu: ColorRect
var _to_menu: Button
var _pause_btn: Button

func _ready() -> void:
	_rng.randomize()
	_retry.pressed.connect(_restart_play)
	var spacing := 360.0 / float(LANES + 1)
	for i in LANES:
		_lane_xs.append(spacing * float(i + 1))
		var b := Button.new()
		b.text = str(i + 1)
		b.size = Vector2(70, 56)
		b.position = Vector2(_lane_xs[i] - 35, 575)
		var lane := i
		b.pressed.connect(func() -> void: _hit(lane))
		$UI.add_child(b)
		_lane_btns.append(b)
	_hit_line.position = Vector2(0, HIT_Y - 2)
	_hit_line.size = Vector2(360, 4)
	_build_shell()
	_show_menu()

func _build_shell() -> void:
	_menu = ColorRect.new()
	_menu.color = Color(0.08, 0.1, 0.16, 1)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left = -130
	vb.offset_top = -150
	vb.offset_right = 130
	vb.offset_bottom = 150
	vb.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "Kannot"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	vb.add_child(title)
	var hi := Label.new()
	hi.name = "High"
	hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hi)
	for d in DIFFS:
		var b := Button.new()
		b.text = str(d["name"])
		b.custom_minimum_size = Vector2(240, 40)
		var did: String = str(d["id"])
		b.pressed.connect(func() -> void: _start_diff(did))
		vb.add_child(b)
	var tip := Label.new()
	tip.text = "1–4 / D F J K · P 暂停"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tip)
	_menu.add_child(vb)
	$UI.add_child(_menu)
	_to_menu = Button.new()
	_to_menu.text = "返回菜单"
	_to_menu.pressed.connect(_show_menu)
	$UI/Overlay/VBox.add_child(_to_menu)
	_pause_btn = Button.new()
	_pause_btn.text = "暂停"
	_pause_btn.position = Vector2(270, 8)
	_pause_btn.size = Vector2(80, 28)
	_pause_btn.pressed.connect(_toggle_pause)
	$UI.add_child(_pause_btn)

func _show_menu() -> void:
	_alive = false
	_paused = false
	_in_menu = true
	_overlay.visible = false
	_menu.visible = true
	_pause_btn.visible = false
	for b in _lane_btns:
		b.visible = false
	for c in _notes_root.get_children():
		c.queue_free()
	(_menu.get_node("VBoxContainer/High") as Label).text = "最高分 %d" % SaveData.high_score
	_hud.text = "Kannot"

func _start_diff(diff_id: String) -> void:
	for d in DIFFS:
		if str(d["id"]) == diff_id:
			_note_speed = float(d["speed"])
			_spawn_min = float(d["spawn_min"])
			_spawn_max = float(d["spawn_max"])
			_song_len = float(d["len"])
			break
	_in_menu = false
	_menu.visible = false
	_pause_btn.visible = true
	for b in _lane_btns:
		b.visible = true
	_restart_play()

func _restart_play() -> void:
	for c in _notes_root.get_children():
		c.queue_free()
	_score = 0
	_combo = 0
	_elapsed = 0.0
	_spawn_cd = 0.6
	_alive = true
	_paused = false
	_overlay.visible = false
	_update_hud()

func _toggle_pause() -> void:
	if not _alive or _in_menu:
		return
	_paused = not _paused
	_update_hud()

func _process(delta: float) -> void:
	if not _alive or _paused or _in_menu:
		return
	_elapsed += delta
	_spawn_cd -= delta
	if _spawn_cd <= 0.0 and _elapsed < _song_len - 2.0:
		_spawn_note()
		_spawn_cd = _rng.randf_range(_spawn_min, _spawn_max)
	for c in _notes_root.get_children():
		var n := c as ColorRect
		n.position.y += _note_speed * delta
		if n.position.y > HIT_Y + 80.0:
			_combo = 0
			n.queue_free()
			_update_hud()
	if _elapsed >= _song_len:
		_end()

func _spawn_note() -> void:
	var lane := _rng.randi_range(0, LANES - 1)
	var r := ColorRect.new()
	r.size = Vector2(48, 20)
	r.color = Color(0.95, 0.75, 0.35)
	r.position = Vector2(_lane_xs[lane] - 24, -24)
	r.set_meta("lane", lane)
	_notes_root.add_child(r)

func _hit(lane: int) -> void:
	if not _alive or _paused or _in_menu:
		return
	var best: ColorRect = null
	var best_dist := 9999.0
	for c in _notes_root.get_children():
		var n := c as ColorRect
		if int(n.get_meta("lane")) != lane:
			continue
		var cy := n.position.y + 10.0
		var d := absf(cy - HIT_Y)
		if d < best_dist:
			best_dist = d
			best = n
	if best == null or best_dist > GOOD:
		_combo = 0
		_update_hud()
		return
	if best_dist <= PERFECT:
		_score += 100
		_combo += 1
	else:
		_score += 50
		_combo += 1
	_score += mini(_combo, 20)
	best.queue_free()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			_toggle_pause()
			return
		if _in_menu or not _alive or _paused:
			return
		match event.keycode:
			KEY_1, KEY_D:
				_hit(0)
			KEY_2, KEY_F:
				_hit(1)
			KEY_3, KEY_J:
				_hit(2)
			KEY_4, KEY_K:
				_hit(3)

func _update_hud() -> void:
	var pause_s := "  [暂停]" if _paused else ""
	_hud.text = "得分 %d  最高 %d\n连击 %d  剩余 %.0fs%s" % [
		_score, SaveData.high_score, _combo, maxf(0.0, _song_len - _elapsed), pause_s
	]

func _end() -> void:
	_alive = false
	var best: int = SaveData.record(_score)
	_over_msg.text = "结束\n得分 %d\n最高 %d" % [_score, best]
	_overlay.visible = true
