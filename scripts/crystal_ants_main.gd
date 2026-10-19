extends Node2D

const CrystalBoard = preload("res://scripts/puzzle/board_model.gd")
const CrystalSolver = preload("res://scripts/puzzle/solver.gd")
const CrystalTelemetry = preload("res://scripts/telemetry/telemetry_service.gd")
const CrystalLocalization = preload("res://scripts/core/localization.gd")

const LEVELS := [
    {"id": "merlion", "name": "MERLION", "subtitle": "Harbour pulse", "seed": 3117, "accent": Color(0.12, 0.86, 0.87), "colors": 4},
    {"id": "marina", "name": "MARINA BAY SANDS", "subtitle": "Skyline drift", "seed": 7841, "accent": Color(0.96, 0.58, 0.34), "colors": 4},
    {"id": "gardens", "name": "GARDENS BY THE BAY", "subtitle": "Supertree bloom", "seed": 15973, "accent": Color(0.56, 0.86, 0.59), "colors": 4},
]
const PALETTE := [Color(0.16, 0.88, 0.92), Color(1.0, 0.42, 0.46), Color(1.0, 0.75, 0.25), Color(0.72, 0.52, 1.0), Color(0.45, 0.95, 0.68), Color(0.36, 0.62, 1.0), Color(1.0, 0.48, 0.75)]
const DARK := Color(0.025, 0.047, 0.10)
const PANEL := Color(0.055, 0.09, 0.18, 0.96)
const PANEL_SOFT := Color(0.08, 0.13, 0.24, 0.82)
const TEXT := Color(0.89, 0.94, 1.0)
const MUTED := Color(0.50, 0.63, 0.77)
const BRIGHT := Color(0.57, 0.95, 0.92)

var loc := CrystalLocalization.new()
var telemetry := CrystalTelemetry.new()
var board: CrystalBoard
var solver_result: Dictionary = {}
var history: Array = []
var current_level := 0
var selected_mode := "Adventure"
var state := "home"
var paused := false
var tutorial_open := true
var completion_open := false
var timed_out := false
var practice_mode := false
var high_contrast := false
var reduced_motion := false
var large_text := false
var animating := false
var animation_time := 0.0
var session_elapsed := 0.0
var feedback_text := ""
var feedback_timer := 0.0
var hint_text := ""
var particles: Array = []
var ant_phase := 0.0
var scores: Array = []
var ui_font: Font
var ui_bold: Font
var title_font: Font

var level_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []
var color_buttons: Array[Button] = []
var action_buttons: Dictionary = {}
var utility_buttons: Dictionary = {}
var overlay_buttons: Array[Button] = []
var leaderboard_button: Button
var practice_button: Button

func _ready() -> void:
    ui_font = ThemeDB.fallback_font
    ui_bold = ThemeDB.fallback_font
    title_font = ThemeDB.fallback_font
    _load_scores()
    _build_ui()
    _set_ui_state()
    queue_redraw()

func _process(delta: float) -> void:
    ant_phase += delta
    if feedback_timer > 0.0:
        feedback_timer -= delta
    if state == "play" and not paused and not timed_out:
        session_elapsed += delta
        if selected_mode == "Time Attack" and session_elapsed >= 90.0 and not board.has_won():
            timed_out = true
            paused = true
            feedback_text = "Time window closed"
            feedback_timer = 3.0
    if animating:
        animation_time += delta
        if animation_time >= (0.22 if reduced_motion else 0.48):
            animating = false
            if board and board.has_won():
                _finish_level()
    for particle in particles:
        particle.life -= delta
        particle.position += particle.velocity * delta
        particle.velocity *= 0.92
    particles = particles.filter(func(p): return p.life > 0.0)
    _layout_ui()
    queue_redraw()

func _build_ui() -> void:
    for index in LEVELS.size():
        var button := _make_button("", 18)
        button.text = "0%d\n%s\n%s" % [index + 1, LEVELS[index].name, LEVELS[index].subtitle]
        button.add_theme_font_size_override("font_size", 17)
        button.pressed.connect(_on_level_pressed.bind(index))
        level_buttons.append(button)
        add_child(button)
    var mode_names := ["Adventure", "Time Attack", "Strategic Challenge", "Daily Challenge", "Research Mode"]
    for mode in mode_names:
        var button := _make_button(mode, 14)
        button.pressed.connect(_on_mode_pressed.bind(mode))
        mode_buttons.append(button)
        add_child(button)
    practice_button = _make_button("Practice mode", 13)
    practice_button.pressed.connect(_toggle_practice)
    add_child(practice_button)
    leaderboard_button = _make_button("Local leaderboard", 13)
    leaderboard_button.pressed.connect(_open_leaderboard)
    add_child(leaderboard_button)
    for colour in 7:
        var button := _make_button("", 18)
        button.text = "%s  %s" % [CrystalBoard.COLOR_ICONS[colour], CrystalBoard.COLOR_NAMES[colour]]
        button.add_theme_color_override("font_color", Color(0.02, 0.06, 0.13, 0.92))
        button.add_theme_color_override("font_hover_color", Color(0.02, 0.06, 0.13, 1.0))
        button.add_theme_stylebox_override("normal", _style(Color(PALETTE[colour].r, PALETTE[colour].g, PALETTE[colour].b, 0.78), Color(1, 1, 1, 0.40), 10, 1))
        button.add_theme_stylebox_override("hover", _style(PALETTE[colour], Color.WHITE, 10, 2))
        button.pressed.connect(_on_colour_pressed.bind(colour))
        color_buttons.append(button)
        add_child(button)
    action_buttons["undo"] = _make_button(loc.t("undo"), 14)
    action_buttons["restart"] = _make_button(loc.t("restart"), 14)
    action_buttons["pause"] = _make_button(loc.t("pause"), 14)
    action_buttons["hint"] = _make_button(loc.t("hint"), 14)
    action_buttons["tutorial"] = _make_button(loc.t("how_to_play"), 14)
    action_buttons["home"] = _make_button(loc.t("back"), 14)
    action_buttons["next"] = _make_button(loc.t("next"), 14)
    for key in action_buttons:
        var button: Button = action_buttons[key]
        add_child(button)
        if key == "undo": button.pressed.connect(_undo_move)
        elif key == "restart": button.pressed.connect(_restart_level)
        elif key == "pause": button.pressed.connect(_toggle_pause)
        elif key == "hint": button.pressed.connect(_show_hint)
        elif key == "tutorial": button.pressed.connect(_toggle_tutorial)
        elif key == "home": button.pressed.connect(_go_home)
        elif key == "next": button.pressed.connect(_next_level)
    utility_buttons["language"] = _make_button(loc.t("language"), 13)
    utility_buttons["contrast"] = _make_button("Contrast", 13)
    utility_buttons["motion"] = _make_button("Motion", 13)
    utility_buttons["text"] = _make_button("Text", 13)
    for key in utility_buttons:
        var button: Button = utility_buttons[key]
        add_child(button)
    utility_buttons["language"].pressed.connect(_toggle_language)
    utility_buttons["contrast"].pressed.connect(_toggle_contrast)
    utility_buttons["motion"].pressed.connect(_toggle_motion)
    utility_buttons["text"].pressed.connect(_toggle_text)

func _make_button(label: String, size: int) -> Button:
    var button := Button.new()
    button.text = label
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_font_size_override("font_size", size)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)
    button.add_theme_stylebox_override("normal", _style(PANEL_SOFT, Color(0.14, 0.24, 0.4), 10, 1))
    button.add_theme_stylebox_override("hover", _style(Color(0.10, 0.20, 0.33), BRIGHT, 10, 2))
    button.add_theme_stylebox_override("pressed", _style(Color(0.12, 0.26, 0.36), BRIGHT, 10, 2))
    button.add_theme_stylebox_override("focus", _style(Color(0.10, 0.20, 0.33), BRIGHT, 10, 2))
    return button

func _style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

func _layout_ui() -> void:
    var size := get_viewport_rect().size
    var scale := 1.08 if large_text else 1.0
    for index in level_buttons.size():
        var x := 72.0 + index * ((size.x - 144.0 - 32.0) / 3.0)
        var card_width := (size.x - 144.0 - 32.0) / 3.0
        level_buttons[index].position = Vector2(x, 322)
        level_buttons[index].size = Vector2(card_width, 190)
    var mode_y := 220.0
    var mode_x := 72.0
    var mode_width: float = min(188.0, (size.x - 144.0) / 5.4)
    for index in mode_buttons.size():
        mode_buttons[index].position = Vector2(mode_x + index * (mode_width + 9.0), mode_y)
        mode_buttons[index].size = Vector2(mode_width, 40)
    practice_button.position = Vector2(72, 532)
    practice_button.size = Vector2(185, 42)
    leaderboard_button.position = Vector2(268, 532)
    leaderboard_button.size = Vector2(185, 42)
    for button in utility_buttons.values():
        button.size = Vector2(82, 34)
    utility_buttons["language"].position = Vector2(size.x - 360, 28)
    utility_buttons["contrast"].position = Vector2(size.x - 270, 28)
    utility_buttons["motion"].position = Vector2(size.x - 180, 28)
    utility_buttons["text"].position = Vector2(size.x - 90, 28)
    if state == "play":
        var layout := _board_layout()
        var side_x: float = layout.x + layout.z + 28.0
        var side_width: float = size.x - side_x - 40.0
        for index in color_buttons.size():
            color_buttons[index].visible = index < board.color_count
            color_buttons[index].position = Vector2(side_x + (index % 2) * (side_width / 2.0 - 5), 352 + int(index / 2) * 54)
            color_buttons[index].size = Vector2(side_width / 2.0 - 10, 44)
            color_buttons[index].add_theme_font_size_override("font_size", int(17 * scale))
        action_buttons["undo"].position = Vector2(side_x, 478)
        action_buttons["undo"].size = Vector2(side_width / 2.0 - 6, 42)
        action_buttons["restart"].position = Vector2(side_x + side_width / 2.0 + 6, 478)
        action_buttons["restart"].size = Vector2(side_width / 2.0 - 6, 42)
        action_buttons["pause"].position = Vector2(side_x, 530)
        action_buttons["pause"].size = Vector2(side_width / 2.0 - 6, 42)
        action_buttons["hint"].position = Vector2(side_x + side_width / 2.0 + 6, 530)
        action_buttons["hint"].size = Vector2(side_width / 2.0 - 6, 42)
        action_buttons["tutorial"].position = Vector2(side_x, 582)
        action_buttons["tutorial"].size = Vector2(side_width, 42)
        action_buttons["home"].position = Vector2(side_x, 634)
        action_buttons["home"].size = Vector2(side_width, 42)
        action_buttons["next"].position = Vector2(side_x, 634)
        action_buttons["next"].size = Vector2(side_width, 42)
    elif state == "complete":
        var side_x := size.x / 2.0 - 220.0
        action_buttons["home"].position = Vector2(side_x, 686)
        action_buttons["home"].size = Vector2(200, 48)
        action_buttons["next"].position = Vector2(side_x + 220, 686)
        action_buttons["next"].size = Vector2(200, 48)
    elif state == "leaderboard":
        action_buttons["home"].position = Vector2(72, 720)
        action_buttons["home"].size = Vector2(220, 48)

func _set_ui_state() -> void:
    var in_play := state == "play"
    var in_complete := state == "complete"
    var in_leaderboard := state == "leaderboard"
    for button in level_buttons:
        button.visible = state == "home"
    for button in mode_buttons:
        button.visible = state == "home"
    practice_button.visible = state == "home"
    leaderboard_button.visible = state == "home"
    for button in color_buttons:
        button.visible = in_play
    for key in action_buttons:
        var button: Button = action_buttons[key]
        button.visible = (in_play and key in ["undo", "restart", "pause", "hint", "tutorial", "home"]) or (in_complete and key in ["home", "next"]) or (in_leaderboard and key == "home")
    for button in utility_buttons.values():
        button.visible = true
    action_buttons["next"].visible = in_complete
    queue_redraw()

func _on_mode_pressed(mode: String) -> void:
    selected_mode = mode
    for index in mode_buttons.size():
        var button: Button = mode_buttons[index]
        var active := button.text == mode
        button.add_theme_stylebox_override("normal", _style(Color(0.10, 0.23, 0.29) if active else PANEL_SOFT, BRIGHT if active else Color(0.14, 0.24, 0.4), 10, 2 if active else 1))
    if mode == "Daily Challenge":
        feedback_text = "Daily seed locked to Singapore"
        feedback_timer = 2.5
    queue_redraw()

func _on_level_pressed(index: int) -> void:
    start_level(index, selected_mode)

func start_level(index: int, mode: String = "Adventure") -> void:
    current_level = index
    selected_mode = mode
    var data: Dictionary = LEVELS[index]
    board = CrystalBoard.new(8, 8, int(data.colors), int(data.seed), data.id)
    solver_result = CrystalSolver.solve(board)
    history = [board.snapshot()]
    session_elapsed = 0.0
    paused = false
    timed_out = false
    completion_open = false
    tutorial_open = not _has_seen_tutorial()
    state = "play"
    hint_text = ""
    feedback_text = ""
    telemetry.start_session("%s-%s" % [data.id, str(data.seed)], "standard-8x8", mode)
    _set_ui_state()
    queue_redraw()

func _on_colour_pressed(colour: int) -> void:
    if state != "play" or paused or animating or tutorial_open or not board:
        return
    var previous_state := board.state_id()
    var previous_captured := board.captured.duplicate()
    var result := board.apply_move(colour)
    if not result.valid:
        feedback_text = "That colour does not touch the colony"
        feedback_timer = 2.0
        return
    history.append(board.snapshot())
    for index in board.total_cells:
        if board.is_captured(index) and not previous_captured[index]:
            _spawn_crystals(index, PALETTE[colour])
    telemetry.record_move(previous_state, colour, board.state_id(), int(result.consumed), int(result.regions_remaining), int(result.remaining_crystals), "%s-%s" % [LEVELS[current_level].id, str(LEVELS[current_level].seed)], "standard-8x8")
    feedback_text = "+%d crystals absorbed" % int(result.consumed)
    feedback_timer = 1.6
    animating = true
    animation_time = 0.0
    hint_text = ""
    queue_redraw()

func _undo_move() -> void:
    if state != "play" or paused or animating or history.size() <= 1:
        return
    history.pop_back()
    board.restore(history.back())
    feedback_text = "Previous state restored"
    feedback_timer = 1.4
    hint_text = ""
    telemetry.record_event("undo", {"puzzle_id": LEVELS[current_level].id, "state_id": board.state_id()})

func _restart_level() -> void:
    if not board:
        return
    start_level(current_level, selected_mode)
    feedback_text = "Fresh board, same seed"
    feedback_timer = 1.5

func _toggle_pause() -> void:
    if state != "play" or tutorial_open:
        return
    paused = not paused
    telemetry.set_paused(paused)
    action_buttons["pause"].text = loc.t("resume") if paused else loc.t("pause")
    queue_redraw()

func _show_hint() -> void:
    if state != "play" or paused or animating:
        return
    var hint: Dictionary
    if solver_result.get("certified", false) and board.move_count < solver_result.path.size():
        hint = {"colour": int(solver_result.path[board.move_count]), "gain": board.preview_gain(int(solver_result.path[board.move_count])), "certified": true}
    else:
        hint = CrystalSolver.greedy_hint(board)
    if int(hint.colour) >= 0:
        hint_text = "Try %s %s  •  +%d crystals%s" % [CrystalBoard.COLOR_ICONS[int(hint.colour)], CrystalBoard.COLOR_NAMES[int(hint.colour)], int(hint.gain), "  •  certified path" if hint.certified else ""]
    else:
        hint_text = "No productive colour is available"

func _toggle_tutorial() -> void:
    tutorial_open = not tutorial_open
    if not tutorial_open:
        _mark_tutorial_seen()
    queue_redraw()

func _toggle_practice() -> void:
    practice_mode = not practice_mode
    practice_button.text = ("Practice mode  •  ON" if practice_mode else "Practice mode  •  OFF")
    queue_redraw()

func _toggle_language() -> void:
    loc.toggle()
    utility_buttons["language"].text = loc.t("language")
    action_buttons["undo"].text = loc.t("undo")
    action_buttons["restart"].text = loc.t("restart")
    action_buttons["pause"].text = loc.t("resume") if paused else loc.t("pause")
    action_buttons["hint"].text = loc.t("hint")
    action_buttons["tutorial"].text = loc.t("how_to_play")
    action_buttons["home"].text = loc.t("back")
    action_buttons["next"].text = loc.t("next")
    queue_redraw()

func _toggle_contrast() -> void:
    high_contrast = not high_contrast
    utility_buttons["contrast"].text = "Contrast  •  ON" if high_contrast else "Contrast"
    queue_redraw()

func _toggle_motion() -> void:
    reduced_motion = not reduced_motion
    utility_buttons["motion"].text = "Motion  •  LOW" if reduced_motion else "Motion"
    queue_redraw()

func _toggle_text() -> void:
    large_text = not large_text
    utility_buttons["text"].text = "Text  •  LARGE" if large_text else "Text"
    queue_redraw()

func _go_home() -> void:
    state = "home"
    paused = false
    completion_open = false
    _set_ui_state()
    queue_redraw()

func _finish_level() -> void:
    if state != "play":
        return
    state = "complete"
    completion_open = true
    var optimal := int(solver_result.get("moves", -1)) if solver_result.get("certified", false) else -1
    var summary := telemetry.finish_session(board.move_count, optimal, LEVELS[current_level].id, "standard-8x8")
    _record_score(summary)
    _set_ui_state()
    queue_redraw()

func _next_level() -> void:
    if current_level < LEVELS.size() - 1:
        start_level(current_level + 1, selected_mode)
    else:
        _go_home()

func _open_leaderboard() -> void:
    state = "leaderboard"
    _set_ui_state()
    queue_redraw()

func _spawn_crystals(index: int, colour: Color) -> void:
    var rect := _board_rect()
    var cell := rect.size.x / float(board.width)
    var x := index % board.width
    var y := int(index / board.width)
    var origin := rect.position + Vector2((x + 0.5) * cell, (y + 0.5) * cell)
    var count := 3 if reduced_motion else 7
    for n in count:
        particles.append({"position": origin, "velocity": Vector2(cos(float(n) * 1.7), sin(float(n) * 1.9)) * (18.0 + n * 4.0), "life": 0.55 + n * 0.04, "colour": colour})

func _board_layout() -> Vector3:
    var viewport := get_viewport_rect().size
    var size: float = min(viewport.y - 238.0, viewport.x - 550.0)
    size = clamp(size, 390.0, 650.0)
    return Vector3(72.0, 144.0, size)

func _board_rect() -> Rect2:
    var layout := _board_layout()
    return Rect2(Vector2(layout.x, layout.y), Vector2(layout.z, layout.z))

func _draw() -> void:
    var viewport := get_viewport_rect().size
    _draw_background(viewport)
    if state == "home":
        _draw_home(viewport)
    elif state == "play":
        _draw_play(viewport)
    elif state == "complete":
        _draw_play(viewport)
        _draw_completion(viewport)
    elif state == "leaderboard":
        _draw_leaderboard(viewport)

func _draw_background(viewport: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, viewport), DARK)
    for index in 12:
        var y := float(index) * viewport.y / 12.0
        var alpha := 0.08 - float(index) * 0.003
        draw_line(Vector2(0, y), Vector2(viewport.x, y + 120), Color(0.12, 0.29, 0.42, alpha), 1.0)
    draw_circle(Vector2(viewport.x * 0.84, viewport.y * 0.10), 220.0, Color(0.11, 0.39, 0.45, 0.12))
    draw_circle(Vector2(viewport.x * 0.18, viewport.y * 0.78), 290.0, Color(0.24, 0.19, 0.48, 0.11))
    draw_string(ui_font, Vector2(72, 64), loc.t("title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, BRIGHT)
    draw_string(ui_font, Vector2(72, 92), loc.t("subtitle"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
    draw_string(ui_font, Vector2(viewport.x - 350, 72), "COGNITIVE STRATEGY / v1.0", HORIZONTAL_ALIGNMENT_RIGHT, 280, 11, MUTED)

func _draw_home(viewport: Vector2) -> void:
    draw_string(title_font, Vector2(72, 156), "A LIVING MOSAIC OF SINGAPORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TEXT)
    draw_string(ui_font, Vector2(72, 194), loc.t("tagline"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, MUTED)
    draw_string(ui_font, Vector2(72, 300), loc.t("choose_landmark"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
    for index in LEVELS.size():
        var x := 72.0 + index * ((viewport.x - 176.0) / 3.0)
        var w := (viewport.x - 208.0) / 3.0
        var rect := Rect2(x, 322, w, 190)
        draw_style_box(_style(Color(0.055, 0.09, 0.18, 0.88), LEVELS[index].accent, 18, 1), rect)
        _draw_landmark(LEVELS[index].id, rect.grow(-18), LEVELS[index].accent, 0.42)
        draw_string(ui_font, Vector2(rect.position.x + 22, rect.position.y + 166), "0%d  /  %s" % [index + 1, LEVELS[index].subtitle.to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_string(ui_font, Vector2(72, 624), "Five ways to play", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
    draw_string(ui_font, Vector2(72, 650), "Every move is an atomic expansion. No diagonal shortcuts.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
    draw_string(ui_font, Vector2(viewport.x - 430, 560), "LOCAL RESEARCH-SAFE TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BRIGHT)
    draw_string(ui_font, Vector2(viewport.x - 430, 584), "Anonymous session events • monotonic timings", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
    draw_string(ui_font, Vector2(viewport.x - 430, 608), "No clinical score is inferred from play.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)

func _draw_play(viewport: Vector2) -> void:
    var accent: Color = LEVELS[current_level].accent
    var layout := _board_layout()
    var board_rect := _board_rect()
    draw_string(title_font, Vector2(72, 118), LEVELS[current_level].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TEXT)
    draw_string(ui_font, Vector2(72, 137), "%s  /  %s" % [selected_mode.to_upper(), LEVELS[current_level].subtitle], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent)
    _draw_landmark(LEVELS[current_level].id, Rect2(layout.x + layout.z * 0.18, 126, layout.z * 0.65, 120), accent, 0.12)
    draw_style_box(_style(Color(0.02, 0.04, 0.09, 0.96), Color(0.18, 0.32, 0.48), 18, 1), board_rect.grow(8))
    _draw_board(board_rect)
    var side_x := layout.x + layout.z + 28.0
    var side_width := viewport.x - side_x - 40.0
    draw_style_box(_style(PANEL, Color(0.14, 0.24, 0.4), 18, 1), Rect2(side_x - 16, 144, side_width + 16, 552))
    draw_string(ui_font, Vector2(side_x, 180), "COLONY CONTROL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BRIGHT)
    draw_string(ui_font, Vector2(side_x, 208), loc.t("select_colour"), HORIZONTAL_ALIGNMENT_LEFT, side_width, 14, TEXT)
    var progress := int(float(board.captured_count) / float(board.total_cells) * 100.0)
    draw_string(ui_font, Vector2(side_x, 260), loc.t("progress"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
    draw_string(ui_bold, Vector2(side_x, 300), "%02d%%" % progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, TEXT)
    draw_string(ui_font, Vector2(side_x + side_width * 0.55, 260), loc.t("moves"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
    draw_string(ui_bold, Vector2(side_x + side_width * 0.55, 300), str(board.move_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, accent)
    draw_string(ui_font, Vector2(side_x, 338), "TIME  %s" % _format_time(session_elapsed), HORIZONTAL_ALIGNMENT_LEFT, side_width, 11, MUTED)
    if selected_mode == "Time Attack":
        draw_string(ui_font, Vector2(side_x + side_width * 0.55, 338), "90 SEC", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.55, 0.45))
    elif selected_mode == "Strategic Challenge":
        draw_string(ui_font, Vector2(side_x + side_width * 0.55, 338), "BUDGET %02d" % (int(solver_result.get("moves", 12)) + 3), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.75, 0.25))
    if solver_result.get("certified", false):
        draw_string(ui_font, Vector2(side_x, 320), "%s  /  %d moves" % [loc.t("certified"), int(solver_result.moves)], HORIZONTAL_ALIGNMENT_LEFT, side_width, 11, BRIGHT)
    else:
        draw_string(ui_font, Vector2(side_x, 320), loc.t("uncertified"), HORIZONTAL_ALIGNMENT_LEFT, side_width, 11, MUTED)
    if practice_mode:
        draw_string(ui_font, Vector2(side_x, 688), "PRACTICE  •  no penalties", HORIZONTAL_ALIGNMENT_LEFT, side_width, 11, Color(0.45, 0.95, 0.68))
    if feedback_timer > 0.0:
        draw_string(ui_bold, Vector2(72, 700), feedback_text, HORIZONTAL_ALIGNMENT_LEFT, 620, 16, accent)
    if hint_text != "":
        draw_style_box(_style(Color(0.09, 0.20, 0.24, 0.94), accent, 10, 1), Rect2(side_x - 4, 700, side_width - 12, 56))
        draw_string(ui_font, Vector2(side_x + 12, 734), hint_text, HORIZONTAL_ALIGNMENT_LEFT, side_width - 32, 13, TEXT)
    if paused or tutorial_open:
        _draw_pause_or_tutorial(viewport)

func _draw_board(rect: Rect2) -> void:
    if not board:
        return
    var cell := rect.size.x / float(board.width)
    for index in board.total_cells:
        var x := index % board.width
        var y := int(index / board.width)
        var tile := Rect2(rect.position + Vector2(x * cell + 2, y * cell + 2), Vector2(cell - 4, cell - 4))
        var colour: Color = PALETTE[board.cell_color(index)]
        var captured := board.is_captured(index)
        var fill := colour if captured else Color(colour.r * 0.56, colour.g * 0.56, colour.b * 0.60, 0.92)
        if high_contrast:
            fill = Color(colour.r, colour.g, colour.b, 0.96) if captured else Color(0.07, 0.09, 0.14, 1)
        draw_style_box(_style(fill, Color(1, 1, 1, 0.32 if captured else 0.13), 7, 1), tile)
        draw_line(tile.position + Vector2(5, 5), tile.position + Vector2(tile.size.x - 7, 5), Color(1, 1, 1, 0.30 if captured else 0.13), 1.0)
        if not captured:
            draw_circle(tile.position + tile.size / 2.0, 4.0, Color(0.04, 0.07, 0.14, 0.35))
        if high_contrast or board.color_count <= 4:
            var icon: String = CrystalBoard.COLOR_ICONS[board.cell_color(index)]
            draw_string(ui_bold, tile.position + Vector2(tile.size.x / 2.0 - 6, tile.position.y + tile.size.y / 2.0 + 6), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.02, 0.06, 0.13, 0.76) if captured else Color(0.86, 0.94, 1, 0.46))
    _draw_ants(rect)
    for particle in particles:
        var alpha: float = clamp(float(particle.life) * 1.8, 0.0, 1.0)
        draw_circle(particle.position, 2.5 + particle.life * 3.0, Color(particle.colour.r, particle.colour.g, particle.colour.b, alpha))

func _draw_ants(rect: Rect2) -> void:
    if not board:
        return
    var cells: Array[int] = []
    for index in board.total_cells:
        if board.is_captured(index):
            cells.append(index)
    var count: int = min(5, cells.size())
    var cell_size := rect.size.x / float(board.width)
    for ant_index in count:
        var source: int = cells[(ant_index * 7 + int(ant_phase * 2.0)) % cells.size()]
        var x: int = source % board.width
        var y: int = int(source / board.width)
        var center := rect.position + Vector2((x + 0.5) * cell_size, (y + 0.5) * cell_size)
        center += Vector2(sin(ant_phase * 2.4 + ant_index) * 4.0, cos(ant_phase * 2.0 + ant_index * 1.4) * 3.0)
        var ant_colour := Color(0.03, 0.06, 0.12, 0.95)
        draw_circle(center, 5.2, ant_colour)
        draw_circle(center + Vector2(4, 1), 3.7, ant_colour)
        draw_line(center + Vector2(-2, -4), center + Vector2(-8, -8), ant_colour, 1.4)
        draw_line(center + Vector2(-1, 4), center + Vector2(-7, 8), ant_colour, 1.4)
        draw_line(center + Vector2(4, -3), center + Vector2(9, -7), ant_colour, 1.2)

func _draw_landmark(kind: String, rect: Rect2, accent: Color, alpha: float) -> void:
    var c := Color(accent.r, accent.g, accent.b, alpha)
    var line := Color(accent.r, accent.g, accent.b, alpha * 1.8)
    var mid := rect.position + rect.size / 2.0
    if kind == "merlion":
        draw_circle(mid + Vector2(-rect.size.x * 0.16, 0), rect.size.x * 0.18, c)
        draw_colored_polygon(PackedVector2Array([mid + Vector2(-rect.size.x * 0.28, 10), mid + Vector2(-rect.size.x * 0.04, 10), mid + Vector2(rect.size.x * 0.08, rect.size.y * 0.34), mid + Vector2(-rect.size.x * 0.15, rect.size.y * 0.34)]), c)
        draw_arc(mid + Vector2(-rect.size.x * 0.16, -rect.size.y * 0.03), rect.size.x * 0.23, PI * 0.9, PI * 1.85, 18, line, 4.0)
        draw_line(mid + Vector2(rect.size.x * 0.06, rect.size.y * 0.34), mid + Vector2(rect.size.x * 0.40, rect.size.y * 0.34), line, 4.0)
        draw_line(mid + Vector2(rect.size.x * 0.32, rect.size.y * 0.34), mid + Vector2(rect.size.x * 0.50, rect.size.y * 0.20), line, 3.0)
        draw_line(mid + Vector2(rect.size.x * 0.32, rect.size.y * 0.34), mid + Vector2(rect.size.x * 0.50, rect.size.y * 0.48), line, 3.0)
    elif kind == "marina":
        var base_y := rect.position.y + rect.size.y * 0.78
        draw_line(Vector2(rect.position.x + rect.size.x * 0.06, base_y), Vector2(rect.end.x - rect.size.x * 0.06, base_y), line, 4.0)
        for tower in 3:
            var tx := rect.position.x + rect.size.x * (0.18 + tower * 0.30)
            draw_rect(Rect2(tx, rect.position.y + rect.size.y * (0.26 + (tower % 2) * 0.08), rect.size.x * 0.13, rect.size.y * 0.52), c)
            draw_line(Vector2(tx + rect.size.x * 0.065, rect.position.y + rect.size.y * 0.24), Vector2(tx + rect.size.x * 0.065, base_y), line, 3.0)
        draw_arc(Vector2(mid.x, rect.position.y + rect.size.y * 0.28), rect.size.x * 0.30, PI, TAU, 20, line, 5.0)
        draw_line(Vector2(rect.position.x + rect.size.x * 0.22, rect.position.y + rect.size.y * 0.27), Vector2(rect.position.x + rect.size.x * 0.78, rect.position.y + rect.size.y * 0.27), line, 5.0)
    else:
        var base_y := rect.end.y - rect.size.y * 0.10
        for tree in 4:
            var tx := rect.position.x + rect.size.x * (0.16 + tree * 0.22)
            var height := rect.size.y * (0.48 + (tree % 2) * 0.18)
            draw_line(Vector2(tx, base_y), Vector2(tx, base_y - height), line, 4.0)
            draw_circle(Vector2(tx, base_y - height), rect.size.x * (0.10 + (tree % 2) * 0.025), c)
            draw_arc(Vector2(tx, base_y - height), rect.size.x * 0.18, PI, TAU, 16, line, 2.0)
            draw_line(Vector2(tx, base_y - height * 0.65), Vector2(tx - 12, base_y - height * 0.80), line, 2.0)
            draw_line(Vector2(tx, base_y - height * 0.48), Vector2(tx + 12, base_y - height * 0.62), line, 2.0)
        draw_line(Vector2(rect.position.x + rect.size.x * 0.05, base_y), Vector2(rect.end.x - rect.size.x * 0.05, base_y), line, 3.0)

func _draw_pause_or_tutorial(viewport: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.01, 0.02, 0.06, 0.78))
    var panel := Rect2(viewport.x * 0.50 - 270, viewport.y * 0.50 - 150, 540, 300)
    draw_style_box(_style(Color(0.045, 0.08, 0.16, 0.98), BRIGHT, 20, 2), panel)
    if tutorial_open:
        draw_string(title_font, panel.position + Vector2(34, 58), loc.t("tutorial_title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TEXT)
        draw_string(ui_font, panel.position + Vector2(34, 102), loc.t("tutorial_copy"), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 68, 16, MUTED)
        draw_string(ui_font, panel.position + Vector2(34, 174), "1–4  select colours     U  undo     H  hint     P  pause", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 68, 13, BRIGHT)
        draw_string(ui_font, panel.position + Vector2(34, 218), "Tap a colour or use the large controls on the right.", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 68, 13, TEXT)
        draw_string(ui_font, panel.position + Vector2(34, 260), "Select How to play again to close this guide.", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 68, 12, MUTED)
    else:
        draw_string(title_font, panel.position + Vector2(34, 64), loc.t("pause_title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TEXT)
        draw_string(ui_font, panel.position + Vector2(34, 112), loc.t("pause_copy"), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 68, 17, MUTED)
        draw_string(ui_font, panel.position + Vector2(34, 184), "Press P or choose Resume when you are ready.", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 68, 14, BRIGHT)
        draw_string(ui_font, panel.position + Vector2(34, 232), "No active time is counted while paused.", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 68, 13, TEXT)

func _draw_completion(viewport: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.01, 0.02, 0.06, 0.76))
    var panel := Rect2(viewport.x * 0.50 - 340, 150, 680, 560)
    draw_style_box(_style(Color(0.045, 0.08, 0.16, 0.98), LEVELS[current_level].accent, 24, 2), panel)
    _draw_landmark(LEVELS[current_level].id, Rect2(panel.position + Vector2(40, 34), Vector2(200, 140)), LEVELS[current_level].accent, 0.28)
    draw_string(title_font, panel.position + Vector2(272, 92), loc.t("complete"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TEXT)
    draw_string(ui_font, panel.position + Vector2(272, 126), LEVELS[current_level].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, LEVELS[current_level].accent)
    draw_string(ui_font, panel.position + Vector2(52, 232), loc.t("complete_copy"), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 104, 17, MUTED)
    draw_string(ui_bold, panel.position + Vector2(52, 306), str(board.move_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 52, TEXT)
    draw_string(ui_font, panel.position + Vector2(54, 334), loc.t("moves"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    if solver_result.get("certified", false):
        draw_string(ui_bold, panel.position + Vector2(230, 306), str(solver_result.moves), HORIZONTAL_ALIGNMENT_LEFT, -1, 52, BRIGHT)
        draw_string(ui_font, panel.position + Vector2(232, 334), loc.t("optimal"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
        var efficiency := float(solver_result.moves) / float(max(board.move_count, 1)) * 100.0
        draw_string(ui_bold, panel.position + Vector2(445, 306), "%d%%" % int(efficiency), HORIZONTAL_ALIGNMENT_LEFT, -1, 52, LEVELS[current_level].accent)
        draw_string(ui_font, panel.position + Vector2(447, 334), loc.t("efficiency"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    else:
        draw_string(ui_font, panel.position + Vector2(230, 304), loc.t("uncertified"), HORIZONTAL_ALIGNMENT_LEFT, 330, 14, MUTED)
    draw_string(ui_font, panel.position + Vector2(52, 406), "SESSION  %s" % telemetry.session_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_string(ui_font, panel.position + Vector2(52, 434), "Anonymous telemetry queued locally: %d events" % telemetry.queued_event_count(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRIGHT)
    draw_string(ui_font, panel.position + Vector2(52, 476), "Your result is a game metric, not a clinical assessment.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)

func _draw_leaderboard(viewport: Vector2) -> void:
    draw_string(title_font, Vector2(72, 160), "LOCAL LEADERBOARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, TEXT)
    draw_string(ui_font, Vector2(72, 198), "Anonymous personal bests stored on this device", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
    var panel := Rect2(72, 238, viewport.x - 144, 420)
    draw_style_box(_style(PANEL, Color(0.14, 0.24, 0.4), 18, 1), panel)
    draw_string(ui_font, Vector2(110, 278), "RANK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_string(ui_font, Vector2(190, 278), "LANDMARK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_string(ui_font, Vector2(460, 278), "MOVES", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_string(ui_font, Vector2(580, 278), "EFFICIENCY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    if scores.is_empty():
        draw_string(ui_font, Vector2(110, 350), "Complete a landmark to set your first personal best.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
    else:
        for index in min(scores.size(), 6):
            var item: Dictionary = scores[index]
            var y: float = 326.0 + index * 48.0
            draw_line(Vector2(108, y + 17), Vector2(panel.end.x - 32, y + 17), Color(0.16, 0.24, 0.36, 0.7), 1.0)
            draw_string(ui_bold, Vector2(110, y), "%02d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, BRIGHT)
            draw_string(ui_font, Vector2(190, y), str(item.get("landmark", "Singapore")), HORIZONTAL_ALIGNMENT_LEFT, 240, 15, TEXT)
            draw_string(ui_font, Vector2(460, y), str(item.get("moves", "–")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
            draw_string(ui_font, Vector2(580, y), str(item.get("efficiency", "–")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, LEVELS[0].accent)
    draw_string(ui_font, Vector2(72, 690), "Public rankings are intentionally not connected to this private research queue.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)

func _format_time(seconds: float) -> String:
    return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _mark_tutorial_seen() -> void:
    var file := FileAccess.open("user://crystal_ants_tutorial.flag", FileAccess.WRITE)
    if file:
        file.store_string("seen")

func _has_seen_tutorial() -> bool:
    return FileAccess.file_exists("user://crystal_ants_tutorial.flag")

func _record_score(summary: Dictionary) -> void:
    scores.append({"landmark": LEVELS[current_level].name, "moves": board.move_count, "efficiency": ("%d%%" % int(summary.move_efficiency_index)) if summary.move_efficiency_index >= 0 else "not certified"})
    scores.sort_custom(func(a, b): return int(a.moves) < int(b.moves))
    if scores.size() > 10:
        scores = scores.slice(0, 10)
    var file := FileAccess.open("user://crystal_ants_scores.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(scores))

func _load_scores() -> void:
    if not FileAccess.file_exists("user://crystal_ants_scores.json"):
        return
    var file := FileAccess.open("user://crystal_ants_scores.json", FileAccess.READ)
    if file:
        var parsed = JSON.parse_string(file.get_as_text())
        if parsed is Array:
            scores = parsed

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if tutorial_open:
                tutorial_open = false
                _mark_tutorial_seen()
            elif paused:
                _toggle_pause()
            elif state == "play":
                _go_home()
        elif state == "play" and not tutorial_open:
            if event.keycode == KEY_P:
                _toggle_pause()
            elif event.keycode == KEY_U:
                _undo_move()
            elif event.keycode == KEY_H:
                _show_hint()
            elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
                _on_colour_pressed(event.keycode - KEY_1)
