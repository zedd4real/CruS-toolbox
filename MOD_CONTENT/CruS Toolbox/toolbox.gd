# toolbox.gd — persistent node: Cruelty Squad debug toolbox.
#
# A collection of toggleable helper features for debugging the game. Each has a
# hotkey; the top-left HUD shows the current state.
#
#   F5  — toggle enemy AI          (freeze / unfreeze all enemies)
#   F6  — toggle enemy collision   (walk through enemies)
#   F7  — kill all enemies         (remove them from the level)
#   F8  — toggle god mode          (best-effort: keep player health topped up)
#   F9  — toggle free camera       (fly around with WASD + mouse, noclip-style)
#   F10 — toggle third-person      (camera follows behind player; wheel zooms)
#   F1  — teleport to next target  (cycles through objective enemies)
#   F2  — time scale slower        (x0.5)
#   F3  — time scale reset         (x1.0)
#   F4  — time scale faster        (x2.0)

extends Node

const KEY_AI = KEY_F5
const KEY_COL = KEY_F6
const KEY_KILL = KEY_F7
const KEY_GOD = KEY_F8
const KEY_CAM = KEY_F9
const KEY_TP = KEY_F10
const KEY_TS_SLOW = KEY_F2
const KEY_TS_RESET = KEY_F3
const KEY_TS_FAST = KEY_F4
const KEY_TELEPORT = KEY_F1

# feature state
var ai_off = false
var col_off = false
var god_mode = false
var freecam_on = false
var third_person_on = false

# collision originals, keyed by node, for restore-on-enable
var collision_originals = {}

# free camera
var free_cam = null
var free_orig_cam = null
var free_cam_tr = Transform.IDENTITY
var free_yaw = 0.0
var free_pitch = 0.0
var free_look = Vector2.ZERO

# third-person camera
var third_cam = null
var third_player_cam = null
var third_distance = 4.0
var third_height = 1.2

# HUD
var hud_layer: CanvasLayer
var hud_bg: ColorRect
var hud_label: Label
var flash_text = ""
var flash_until = 0

# hotkey edge detection
var prev_ai = false
var prev_col = false
var prev_kill = false
var prev_god = false
var prev_cam = false
var prev_tp = false
var prev_ts_slow = false
var prev_ts_reset = false
var prev_ts_fast = false
var prev_teleport = false
var teleport_index = 0

# periodic re-freeze + enemy cache
var freeze_frame = 0
var cached_enemies = []
var cache_frame = 0


func _ready() -> void:
    pause_mode = Node.PAUSE_MODE_PROCESS
    _build_hud()
    get_tree().connect("tree_exiting", self, "_on_tree_exiting")
    _render_hud()


func _exit_tree() -> void:
    _cleanup_freecam()
    _cleanup_third_person()


func _build_hud() -> void:
    hud_layer = CanvasLayer.new()
    hud_layer.name = "ToolboxHUD"
    hud_layer.layer = 100
    add_child(hud_layer)

    hud_bg = ColorRect.new()
    hud_bg.color = Color(0, 0, 0, 0.55)
    hud_bg.rect_position = Vector2(8, 8)
    hud_bg.rect_size = Vector2(560, 48)
    hud_layer.add_child(hud_bg)

    hud_label = Label.new()
    hud_label.rect_position = Vector2(14, 10)
    hud_label.rect_size = Vector2(548, 44)
    hud_label.add_color_override("font_color", Color(0.95, 0.95, 0.95))
    hud_layer.add_child(hud_label)


func _input(event) -> void:
    if freecam_on and event is InputEventMouseMotion:
        free_look += event.relative
    if third_person_on and event is InputEventMouseButton:
        if event.button_index == BUTTON_WHEEL_UP and event.pressed:
            third_distance = max(0.5, third_distance - 0.5)
        elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
            third_distance = min(20.0, third_distance + 0.5)


func _physics_process(_delta: float) -> void:
    _poll_hotkeys()
    if ai_off:
        freeze_frame += 1
        if freeze_frame % 30 == 0:
            _set_enemy_ai(false)  # re-freeze newly-spawned enemies
    _apply_god_mode()
    _render_hud()


func _process(delta: float) -> void:
    if freecam_on:
        _drive_freecam(delta)
    if third_person_on:
        _drive_third_person(delta)


func _poll_hotkeys() -> void:
    var ai = Input.is_key_pressed(KEY_AI)
    if ai and not prev_ai:
        ai_off = not ai_off
        _set_enemy_ai(not ai_off)
        _flash("enemy AI " + ("OFF" if ai_off else "ON"))
    prev_ai = ai

    var col = Input.is_key_pressed(KEY_COL)
    if col and not prev_col:
        col_off = not col_off
        _set_enemy_collision(not col_off)
        _flash("enemy collision " + ("OFF" if col_off else "ON"))
    prev_col = col

    var kill = Input.is_key_pressed(KEY_KILL)
    if kill and not prev_kill:
        _kill_all_enemies()
    prev_kill = kill

    var god = Input.is_key_pressed(KEY_GOD)
    if god and not prev_god:
        god_mode = not god_mode
        _flash("god mode " + ("ON" if god_mode else "OFF"))
    prev_god = god

    var cam = Input.is_key_pressed(KEY_CAM)
    if cam and not prev_cam:
        _toggle_freecam()
    prev_cam = cam

    var tp = Input.is_key_pressed(KEY_TP)
    if tp and not prev_tp:
        _toggle_third_person()
    prev_tp = tp

    var slow = Input.is_key_pressed(KEY_TS_SLOW)
    if slow and not prev_ts_slow:
        Engine.time_scale = max(0.0625, Engine.time_scale * 0.5)
        _flash("time scale x%.2f" % Engine.time_scale)
    prev_ts_slow = slow

    var reset = Input.is_key_pressed(KEY_TS_RESET)
    if reset and not prev_ts_reset:
        Engine.time_scale = 1.0
        _flash("time scale x1.00")
    prev_ts_reset = reset

    var fast = Input.is_key_pressed(KEY_TS_FAST)
    if fast and not prev_ts_fast:
        Engine.time_scale = min(8.0, Engine.time_scale * 2.0)
        _flash("time scale x%.2f" % Engine.time_scale)
    prev_ts_fast = fast

    var tel = Input.is_key_pressed(KEY_TELEPORT)
    if tel and not prev_teleport:
        _teleport_to_target()
    prev_teleport = tel


# ------------------------------------------------------------- enemy helpers

func _find_enemy_roots() -> Array:
    var roots = []
    var scene = Global.get("current_scene")
    if scene == null:
        return roots
    _scan_enemies(scene, roots)
    return roots


func _scan_enemies(node, roots) -> void:
    var fn = node.get("filename")
    if fn != null and str(fn).begins_with("res://Entities/Enemies/"):
        roots.append(node)
        return
    var scr = node.get_script()
    if scr != null and "EnemyHandler" in str(scr.get_path()):
        roots.append(node)
        return
    for child in node.get_children():
        _scan_enemies(child, roots)


func _set_enemy_ai(on: bool) -> void:
    var roots = _find_enemy_roots()
    for root in roots:
        _set_recursive_ai(root, on)
    if roots.size() > 0:
        Mod.mod_log("CruS Toolbox: enemy AI " + ("ON" if on else "OFF") + " (" + str(roots.size()) + " roots)", "CruS Toolbox")


func _set_recursive_ai(node, on: bool) -> void:
    node.set_process(on)
    node.set_physics_process(on)
    for child in node.get_children():
        _set_recursive_ai(child, on)


func _set_enemy_collision(on: bool) -> void:
    if on:
        for node in collision_originals.keys():
            if is_instance_valid(node):
                node.collision_layer = collision_originals[node]["layer"]
                node.collision_mask = collision_originals[node]["mask"]
                if node is CollisionShape:
                    node.disabled = false
                if node is CollisionPolygon:
                    node.disabled = false
        collision_originals.clear()
    else:
        collision_originals.clear()
        var roots = _find_enemy_roots()
        for root in roots:
            _disable_collision_recursive(root)
    Mod.mod_log("CruS Toolbox: enemy collision " + ("ON" if on else "OFF"), "CruS Toolbox")


func _disable_collision_recursive(node) -> void:
    if node is CollisionObject:
        if not node in collision_originals:
            collision_originals[node] = {"layer": node.collision_layer, "mask": node.collision_mask}
        node.collision_layer = 0
        node.collision_mask = 0
    if node is CollisionShape:
        node.disabled = true
    if node is CollisionPolygon:
        node.disabled = true
    for child in node.get_children():
        _disable_collision_recursive(child)


func _kill_all_enemies() -> void:
    var roots = _find_enemy_roots()
    for root in roots:
        root.queue_free()
    Mod.mod_log("CruS Toolbox: killed " + str(roots.size()) + " enemies", "CruS Toolbox")
    _flash("killed " + str(roots.size()) + " enemies")


# 目标 NPC（必须击杀才能过关）：场景文件或节点名带 "Obj_" / "Objective" 的敌人。
func _find_target_roots() -> Array:
    var roots = []
    var scene = Global.get("current_scene")
    if scene == null:
        return roots
    _scan_targets(scene, roots)
    return roots


func _scan_targets(node, roots) -> void:
    # definitive signal: the "objective" flag on the EnemyHandler script
    if node.get("objective") == true:
        roots.append(node)
        return
    # fallback: objective scenes are named Obj_* / Chaos_Objective
    var fn = node.get("filename")
    if fn != null:
        var base = str(fn).get_file()
        if base.begins_with("Obj_") or base.begins_with("Chaos_Objective"):
            roots.append(node)
            return
    for child in node.get_children():
        _scan_targets(child, roots)


func _teleport_to_target() -> void:
    if not is_instance_valid(Global.player):
        _flash("no player")
        return
    var targets = _find_target_roots()
    if targets.size() == 0:
        _flash("no targets found")
        return
    if teleport_index >= targets.size():
        teleport_index = 0
    var target = targets[teleport_index]
    teleport_index += 1

    var target_tr = target.global_transform
    var forward = -target_tr.basis.z
    var tp_pos = target_tr.origin + forward * 3.0 + Vector3.UP * 0.5

    var player_tr = Global.player.global_transform
    player_tr.origin = tp_pos
    Global.player.global_transform = player_tr
    Global.player.look_at(target_tr.origin, Vector3.UP)

    Mod.mod_log("CruS Toolbox: teleported to target " + str(target.name) + " (" + str(teleport_index) + "/" + str(targets.size()) + ")", "CruS Toolbox")
    _flash("target %d/%d: %s" % [teleport_index, targets.size(), target.name])


# ------------------------------------------------------------------- god mode

func _apply_god_mode() -> void:
    if not god_mode:
        return
    if not is_instance_valid(Global.player):
        return
    var hp = Global.player.get("health")
    if hp != null:
        Global.player.set("health", 9999.0)
    Global.player.set("died", false)


# 灵魂出窍：冻结玩家处理（移动/视角），自由相机飞行时玩家站着不动。
func _set_player_frozen(frozen: bool) -> void:
    if not is_instance_valid(Global.player):
        return
    _freeze_player_recursive(Global.player, frozen)


func _freeze_player_recursive(node, frozen: bool) -> void:
    node.set_process(not frozen)
    node.set_physics_process(not frozen)
    node.set_process_input(not frozen)
    node.set_process_unhandled_input(not frozen)
    for child in node.get_children():
        _freeze_player_recursive(child, frozen)


# ---------------------------------------------------------------- free camera

func _toggle_freecam() -> void:
    freecam_on = not freecam_on
    if freecam_on:
        _cleanup_third_person()
        free_orig_cam = get_viewport().get_camera()
        free_cam = Camera.new()
        free_cam.name = "ToolboxFreeCam"
        free_cam.fov = free_orig_cam.fov if free_orig_cam != null else 75.0
        get_tree().root.add_child(free_cam)
        free_cam.current = true
        if free_orig_cam != null:
            free_orig_cam.current = false
        free_cam_tr = free_orig_cam.global_transform if free_orig_cam != null else Transform.IDENTITY
        free_cam.global_transform = free_cam_tr
        var e = free_cam_tr.basis.get_euler()
        free_yaw = e.y
        free_pitch = e.x
        free_look = Vector2.ZERO
        _set_player_frozen(true)
        _flash("free camera ON")
    else:
        _cleanup_freecam()
        _flash("free camera OFF")


func _cleanup_freecam() -> void:
    freecam_on = false
    _set_player_frozen(false)
    if is_instance_valid(free_orig_cam):
        free_orig_cam.current = true
    free_orig_cam = null
    if is_instance_valid(free_cam):
        free_cam.queue_free()
    free_cam = null


func _drive_freecam(delta: float) -> void:
    free_yaw -= free_look.x * 0.0025
    free_pitch = clamp(free_pitch - free_look.y * 0.0025, -1.55, 1.55)
    free_look = Vector2.ZERO

    var basis = Basis(Vector3.UP, free_yaw) * Basis(Vector3.RIGHT, free_pitch)
    free_cam_tr.basis = basis

    var dir = Vector3.ZERO
    if Input.is_key_pressed(KEY_W):
        dir -= basis.z
    if Input.is_key_pressed(KEY_S):
        dir += basis.z
    if Input.is_key_pressed(KEY_A):
        dir -= basis.x
    if Input.is_key_pressed(KEY_D):
        dir += basis.x
    if Input.is_key_pressed(KEY_SPACE):
        dir += Vector3.UP
    if Input.is_key_pressed(KEY_CONTROL):
        dir -= Vector3.UP

    var spd = 20.0 if Input.is_key_pressed(KEY_SHIFT) else 8.0
    if dir != Vector3.ZERO:
        free_cam_tr.origin += dir.normalized() * spd * delta

    free_cam.global_transform = free_cam_tr


# -------------------------------------------------------------- third person

func _toggle_third_person() -> void:
    if freecam_on:
        _cleanup_freecam()
    third_person_on = not third_person_on
    if third_person_on:
        third_player_cam = get_viewport().get_camera()
        third_cam = Camera.new()
        third_cam.name = "ToolboxThirdCam"
        third_cam.fov = third_player_cam.fov if third_player_cam != null else 75.0
        get_tree().root.add_child(third_cam)
        third_cam.current = true
        if third_player_cam != null:
            third_player_cam.current = false
        third_distance = 4.0
        _flash("third-person ON")
    else:
        _cleanup_third_person()
        _flash("third-person OFF")


func _cleanup_third_person() -> void:
    third_person_on = false
    if is_instance_valid(third_player_cam):
        third_player_cam.current = true
    third_player_cam = null
    if is_instance_valid(third_cam):
        third_cam.queue_free()
    third_cam = null


func _drive_third_person(_delta: float) -> void:
    if not is_instance_valid(third_player_cam) or not is_instance_valid(third_cam):
        return
    var tr = third_player_cam.global_transform
    var forward = -tr.basis.z
    var cam_pos = tr.origin - forward * third_distance + Vector3.UP * third_height
    third_cam.global_transform = Transform(tr.basis, cam_pos)


# -------------------------------------------------------------------- helpers

func _flash(msg: String) -> void:
    flash_text = msg
    flash_until = OS.get_ticks_msec() + 2500


func _on_tree_exiting() -> void:
    _cleanup_freecam()
    _cleanup_third_person()


# ----------------------------------------------------------------------- HUD

func _render_hud() -> void:
    var now = OS.get_ticks_msec()
    if flash_text != "" and now < flash_until:
        hud_label.text = flash_text
        return

    var pos_str = "?"
    var hp_str = "?"
    if is_instance_valid(Global.player):
        var p = Global.player.global_transform.origin
        pos_str = "%.1f %.1f %.1f" % [p.x, p.y, p.z]
        var hp = Global.player.get("health")
        if hp != null:
            hp_str = str(int(hp))

    var enemies = _cached_enemy_count()

    var line1 = "AI:%s  COL:%s  GOD:%s  CAM:%s  TP:%s  TS:%.2fx" % [
        "OFF" if ai_off else "ON",
        "OFF" if col_off else "ON",
        "ON" if god_mode else "OFF",
        "ON" if freecam_on else "OFF",
        "ON" if third_person_on else "OFF",
        Engine.time_scale
    ]
    var line2 = "POS %s   HP %s   ENEMIES %d" % [pos_str, hp_str, enemies]
    hud_label.text = line1 + "\n" + line2


func _cached_enemy_count() -> int:
    cache_frame += 1
    if cache_frame % 30 == 0 or cached_enemies.size() == 0:
        cached_enemies = _find_enemy_roots()
    return cached_enemies.size()
