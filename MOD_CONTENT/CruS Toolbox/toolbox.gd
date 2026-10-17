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
#   V   — toggle noclip            (fly freely; player follows; can shoot)
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
const KEY_NOCLIP = KEY_V
const KEY_TS_SLOW = KEY_F2
const KEY_TS_RESET = KEY_F3
const KEY_TS_FAST = KEY_F4
const KEY_TELEPORT = KEY_F1
const KEY_DIFF = KEY_F11
const KEY_SPAWN = KEY_B
const KEY_OUTLINE = KEY_H
const DIFF_NAMES = ["Divine Light", "Flesh Automaton", "Power In Misery", "Hope Eradicated"]
const SPAWN_LIST = [
    ["Grunt", "res://Entities/Enemies/E_Grunt.tscn"],
    ["Civilian", "res://Entities/Enemies/E_Civilian.tscn"],
    ["Civilian Female", "res://Entities/Enemies/E_Civilian_Female.tscn"],
    ["Civilian Worker", "res://Entities/Enemies/E_Civilian_Worker.tscn"],
    ["Cop Shotgun", "res://Entities/Enemies/E_Cop_Shotgun.tscn"],
    ["Cop Revolver", "res://Entities/Enemies/E_Cop_Revolver.tscn"],
    ["Cult Grunt", "res://Entities/Enemies/E_Cult_Grunt.tscn"],
    ["Cult Sniper", "res://Entities/Enemies/E_Cultist_Sniper.tscn"],
    ["Dog", "res://Entities/Enemies/E_Dog.tscn"],
    ["Pig", "res://Entities/Enemies/E_Pig.tscn"],
    ["Pig 2", "res://Entities/Enemies/E_Pig2.tscn"],
    ["Knifelord", "res://Entities/Enemies/E_Knifelord.tscn"],
    ["Flower", "res://Entities/Enemies/E_Flower.tscn"],
    ["Security", "res://Entities/Enemies/E_Security.tscn"],
    ["Elite", "res://Entities/Enemies/E_Elite.tscn"],
    ["Zombie", "res://Entities/Enemies/E_Zombie.tscn"],
    ["Fleshrat", "res://Entities/Enemies/E_Fleshrat.tscn"],
    ["Fleshman", "res://Entities/Enemies/E_Fleshman.tscn"],
    ["Killerbot", "res://Entities/Enemies/E_Killerbot.tscn"],
    ["Orbot", "res://Entities/Enemies/E_Orbot.tscn"],
    ["Assassin", "res://Entities/Enemies/E_Assassin.tscn"],
    ["Swamp Sniper", "res://Entities/Enemies/E_Swamp_Sniper.tscn"],
    ["Psycho", "res://Entities/Enemies/E_Psycho.tscn"],
    ["Paratrooper", "res://Entities/Enemies/E_Paratrooper.tscn"],
    ["CEO (目标)", "res://Entities/Enemies/Obj_CEO.tscn"],
    ["Chief (目标)", "res://Entities/Enemies/Obj_Chief.tscn"],
    ["Pinky (目标)", "res://Entities/Enemies/Obj_Pinky.tscn"],
    ["Cult Leader (目标)", "res://Entities/Enemies/Obj_Cult_Leader.tscn"],
    ["Nerd (目标)", "res://Entities/Enemies/Obj_Nerd_1.tscn"],
    ["Nude (目标)", "res://Entities/Enemies/Obj_Nude_1.tscn"],
    ["Swampgod (目标)", "res://Entities/Enemies/Obj_Swampgod.tscn"],
    ["Chaos Objective", "res://Entities/Enemies/Chaos_Objective.tscn"],
]

# feature state
var ai_off = false
var col_off = false
var god_mode = false
var freecam_on = false
var third_person_on = false
var noclip_on = false
var outline_on = false
var outline_mat = null
var outline_frame = 0
var outline_originals = {}
var mouse_actions = []

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

# noclip (fly the player directly; keeps its own camera + shooting)
var noclip_col_layer = 1
var noclip_target_pos = Vector3.ZERO

# HUD
var hud_layer: CanvasLayer
var hud_bg: ColorRect
var hud_label: Label
var diff_button: OptionButton
var diff_menu_on = false
var prev_mouse_mode = Input.MOUSE_MODE_CAPTURED
var spawn_list: ItemList
var spawn_bg: ColorRect
var spawn_minus_btn: Button
var spawn_plus_btn: Button
var spawn_menu_on = false
var spawn_point = Vector3.ZERO
var spawn_scale = 1.0
var flash_text = ""
var flash_until = 0

# hotkey edge detection
var prev_ai = false
var prev_col = false
var prev_kill = false
var prev_god = false
var prev_cam = false
var prev_tp = false
var prev_noclip = false
var prev_diff = false
var prev_spawn = false
var prev_outline = false
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
    # 缓存所有绑定到鼠标按键的动作，菜单打开时释放，防止点菜单时开火
    for action in InputMap.get_actions():
        for event in InputMap.get_action_list(action):
            if event is InputEventMouseButton:
                mouse_actions.append(action)
                break


func _exit_tree() -> void:
    _cleanup_freecam()
    _cleanup_third_person()
    _cleanup_noclip()


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

    diff_button = OptionButton.new()
    diff_button.rect_position = Vector2(8, 56)
    diff_button.rect_min_size = Vector2(210, 28)
    for n in DIFF_NAMES:
        diff_button.add_item(n)
    diff_button.select(_current_difficulty_idx())
    diff_button.visible = false
    diff_button.connect("item_selected", self, "_on_diff_selected")
    hud_layer.add_child(diff_button)

    spawn_bg = ColorRect.new()
    spawn_bg.rect_position = Vector2(8, 90)
    spawn_bg.color = Color(0, 0, 0, 0.8)
    spawn_bg.visible = false
    hud_layer.add_child(spawn_bg)

    spawn_list = ItemList.new()
    spawn_list.rect_position = Vector2(8, 90)
    for entry in SPAWN_LIST:
        spawn_list.add_item(entry[0])
    spawn_list.visible = false
    spawn_list.connect("item_selected", self, "_on_spawn_selected")
    hud_layer.add_child(spawn_list)

    spawn_minus_btn = Button.new()
    spawn_minus_btn.text = "-"
    spawn_minus_btn.rect_position = Vector2(8, 52)
    spawn_minus_btn.rect_size = Vector2(44, 34)
    spawn_minus_btn.visible = false
    spawn_minus_btn.connect("pressed", self, "_on_spawn_minus")
    hud_layer.add_child(spawn_minus_btn)

    spawn_plus_btn = Button.new()
    spawn_plus_btn.text = "+"
    spawn_plus_btn.rect_position = Vector2(56, 52)
    spawn_plus_btn.rect_size = Vector2(44, 34)
    spawn_plus_btn.visible = false
    spawn_plus_btn.connect("pressed", self, "_on_spawn_plus")
    hud_layer.add_child(spawn_plus_btn)

    _apply_spawn_scale()


func _input(event) -> void:
    if freecam_on and event is InputEventMouseMotion:
        free_look += event.relative
    if third_person_on and event is InputEventMouseButton:
        if event.button_index == BUTTON_WHEEL_UP and event.pressed:
            third_distance = max(0.5, third_distance - 0.5)
        elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
            third_distance = min(20.0, third_distance + 0.5)
    if (spawn_menu_on or diff_menu_on) and event is InputEventMouseButton:
        for action in mouse_actions:
            Input.action_release(action)


func _physics_process(_delta: float) -> void:
    _poll_hotkeys()
    if ai_off:
        freeze_frame += 1
        if freeze_frame % 30 == 0:
            _set_enemy_ai(false)  # re-freeze newly-spawned enemies
    if outline_on:
        outline_frame += 1
        if outline_frame % 30 == 0:
            _set_outline(true)  # re-apply to newly-spawned enemies
    _apply_god_mode()
    _render_hud()


func _process(delta: float) -> void:
    if freecam_on:
        _drive_freecam(delta)
    if third_person_on:
        _drive_third_person(delta)
    if noclip_on:
        _drive_noclip(delta)


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

    var nc = Input.is_key_pressed(KEY_NOCLIP)
    if nc and not prev_noclip:
        _toggle_noclip()
    prev_noclip = nc

    var df = Input.is_key_pressed(KEY_DIFF)
    if df and not prev_diff:
        _toggle_diff_menu()
    prev_diff = df

    var sp = Input.is_key_pressed(KEY_SPAWN)
    if sp and not prev_spawn:
        _toggle_spawn_menu()
    prev_spawn = sp

    var ol = Input.is_key_pressed(KEY_OUTLINE)
    if ol and not prev_outline:
        _toggle_outline()
    prev_outline = ol

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
func _toggle_outline() -> void:
    outline_on = not outline_on
    if outline_on:
        outline_mat = _make_outline_material()  # 每次开启都重新创建，避免复用旧材质失效
        outline_originals.clear()
    _set_outline(outline_on)
    _flash("enemy outline " + ("ON" if outline_on else "OFF"))


func _make_outline_material() -> ShaderMaterial:
    var shader = Shader.new()
    shader.code = "shader_type spatial;\nrender_mode cull_front, unshaded;\nvoid vertex() {\n\tVERTEX += NORMAL * 0.05;\n}\nvoid fragment() {\n\tALBEDO = vec3(1.0, 0.0, 0.0);\n}"
    var mat = ShaderMaterial.new()
    mat.shader = shader
    return mat


func _set_outline(on: bool) -> void:
    var enemies = _find_enemy_roots()
    for root in enemies:
        if root.get("civilian") == true:
            continue  # 跳过平民
        _set_outline_recursive(root, on)


func _set_outline_recursive(node, on: bool) -> void:
    if node is MeshInstance:
        if on:
            if not node in outline_originals:
                outline_originals[node] = {
                    "override": node.material_override,
                    "surface0": node.get_surface_material(0)
                }
            var base = outline_originals[node]["override"]
            if base == null:
                base = outline_originals[node]["surface0"]
            if base != null:
                var mat = base.duplicate()
                mat.next_pass = outline_mat
                node.material_override = mat
            else:
                node.material_override = outline_mat  # 无材质，直接空心红描边
        else:
            if node in outline_originals:
                node.material_override = outline_originals[node]["override"]
            else:
                node.material_override = null
    for child in node.get_children():
        _set_outline_recursive(child, on)


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
        _cleanup_noclip()
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
    if noclip_on:
        _cleanup_noclip()
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


# ------------------------------------------------------------------- noclip

func _toggle_noclip() -> void:
    if freecam_on:
        _cleanup_freecam()
    if third_person_on:
        _cleanup_third_person()
    noclip_on = not noclip_on
    if noclip_on:
        _enter_noclip()
    else:
        _cleanup_noclip()


# 真 noclip：直接移动玩家本体，保留玩家自己的视角和开火（不建独立相机）
func _enter_noclip() -> void:
    if not is_instance_valid(Global.player):
        noclip_on = false
        return
    noclip_col_layer = Global.player.get("collision_layer")
    Global.player.set("collision_layer", 0)
    var cb = Global.player.get("collision_box")
    if cb != null:
        cb.set("disabled", true)
    var cc = Global.player.get("crush_check")
    if cc != null:
        cc.set("disabled", true)
    var body = Global.player.get_node_or_null("Body_Mesh")
    if body != null:
        body.visible = false
    noclip_target_pos = Global.player.global_transform.origin
    _flash("noclip ON")


func _cleanup_noclip() -> void:
    noclip_on = false
    if is_instance_valid(Global.player):
        Global.player.set("collision_layer", noclip_col_layer)
        var cb = Global.player.get("collision_box")
        if cb != null:
            cb.set("disabled", false)
        var cc = Global.player.get("crush_check")
        if cc != null:
            cc.set("disabled", false)
        var body = Global.player.get_node_or_null("Body_Mesh")
        if body != null:
            body.visible = true
    _flash("noclip OFF")


func _drive_noclip(delta: float) -> void:
    if not is_instance_valid(Global.player):
        return
    var cam = get_viewport().get_camera()
    var dir = Vector3.ZERO
    if cam != null:
        var fwd = -cam.global_transform.basis.z
        var right = cam.global_transform.basis.x
        if Input.is_key_pressed(KEY_W):
            dir += fwd
        if Input.is_key_pressed(KEY_S):
            dir -= fwd
        if Input.is_key_pressed(KEY_D):
            dir += right
        if Input.is_key_pressed(KEY_A):
            dir -= right
    if Input.is_key_pressed(KEY_SPACE):
        dir += Vector3.UP
    if Input.is_key_pressed(KEY_CONTROL):
        dir -= Vector3.UP
    if dir != Vector3.ZERO:
        var spd = 20.0 if Input.is_key_pressed(KEY_ALT) else 8.0
        noclip_target_pos += dir.normalized() * spd * delta
    # 始终覆盖位置 + 清空速度，抵消重力（不碰 max_gravity，避免反转视角）
    var ptr = Global.player.global_transform
    ptr.origin = noclip_target_pos
    Global.player.global_transform = ptr
    Global.player.set("player_velocity", Vector3.ZERO)


# -------------------------------------------------------------------- helpers

func _flash(msg: String) -> void:
    flash_text = msg
    flash_until = OS.get_ticks_msec() + 2500


# 难度切换下拉菜单
func _toggle_diff_menu() -> void:
    if spawn_menu_on:
        spawn_menu_on = false
        spawn_list.visible = false
        spawn_bg.visible = false
        spawn_minus_btn.visible = false
        spawn_plus_btn.visible = false
    diff_menu_on = not diff_menu_on
    diff_button.visible = diff_menu_on
    if diff_menu_on:
        diff_button.select(_current_difficulty_idx())
        prev_mouse_mode = Input.get_mouse_mode()
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    else:
        Input.set_mouse_mode(prev_mouse_mode)


func _on_diff_selected(idx: int) -> void:
    _set_difficulty(idx)
    _toggle_diff_menu()


func _set_difficulty(idx: int) -> void:
    # 四个难度标志（对应存档 soul/hell_discovered/husk/hope），先全部置 false
    Global.set("soul_intact", false)
    Global.set("hell_discovered", false)
    Global.set("husk_mode", false)
    Global.set("hope_discarded", false)
    # 再设选中的为 true
    if idx == 0:
        Global.set("soul_intact", true)  # Divine Light
    elif idx == 1:
        Global.set("hell_discovered", true)  # Flesh Automaton
    elif idx == 2:
        Global.set("husk_mode", true)  # Power In Misery
    elif idx == 3:
        Global.set("hope_discarded", true)  # Hope Eradicated
    # 直接写存档文件（可靠持久化，像 save editor 那样）
    _write_difficulty_to_save(idx)
    _flash("difficulty: " + DIFF_NAMES[idx])
    Mod.mod_log("CruS Toolbox: difficulty set -> " + DIFF_NAMES[idx], "CruS Toolbox")


func _write_difficulty_to_save(idx: int) -> void:
    var f = File.new()
    if not f.file_exists("user://savegame.save"):
        return
    f.open("user://savegame.save", File.READ)
    var text = f.get_as_text()
    f.close()
    var parsed = JSON.parse(text)
    if parsed.error != OK or typeof(parsed.result) != TYPE_DICTIONARY:
        Mod.mod_log("CruS Toolbox: save parse failed", "CruS Toolbox")
        return
    var data = parsed.result
    data["soul"] = (idx == 0)
    data["hell_discovered"] = (idx == 1)
    data["husk"] = (idx == 2)
    data["hope"] = (idx == 3)
    f.open("user://savegame.save", File.WRITE)
    f.store_string(JSON.print(data))
    f.close()
    Mod.mod_log("CruS Toolbox: savegame.save written", "CruS Toolbox")


func _current_difficulty_idx() -> int:
    if Global.get("hope_discarded"):
        return 3
    if Global.get("husk_mode"):
        return 2
    if Global.get("hell_discovered"):
        return 1
    return 0  # soul_intact = Divine Light


# GMod 式 B 键生成菜单
func _toggle_spawn_menu() -> void:
    if diff_menu_on:
        diff_menu_on = false
        diff_button.visible = false
    spawn_menu_on = not spawn_menu_on
    spawn_list.visible = spawn_menu_on
    spawn_bg.visible = spawn_menu_on
    spawn_minus_btn.visible = spawn_menu_on
    spawn_plus_btn.visible = spawn_menu_on
    if spawn_menu_on:
        spawn_point = _get_crosshair_point()
        prev_mouse_mode = Input.get_mouse_mode()
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    else:
        Input.set_mouse_mode(prev_mouse_mode)


func _on_spawn_selected(idx: int) -> void:
    if idx >= 0 and idx < SPAWN_LIST.size():
        _spawn_npc(SPAWN_LIST[idx][1])


func _spawn_npc(path: String) -> void:
    var packed = load(path)
    if packed == null:
        _flash("spawn failed: " + path)
        return
    var npc = packed.instance()
    if npc == null:
        return
    npc.translation = spawn_point
    var scene = Global.get("current_scene")
    if scene != null:
        scene.add_child(npc)
    else:
        get_tree().root.add_child(npc)
    Mod.mod_log("CruS Toolbox: spawned " + path.get_file(), "CruS Toolbox")


func _get_crosshair_point() -> Vector3:
    var cam = get_viewport().get_camera()
    if cam == null:
        return Vector3.ZERO
    var from = cam.global_transform.origin
    var dir = -cam.global_transform.basis.z
    var to = from + dir * 500.0
    var space = cam.get_world().direct_space_state
    var hit = space.intersect_ray(from, to)
    if hit.empty():
        return to
    return hit["position"]


func _apply_spawn_scale() -> void:
    spawn_bg.rect_size = Vector2(440, 620) * spawn_scale
    spawn_list.rect_size = Vector2(440, 620) * spawn_scale
    var dfont = DynamicFont.new()
    dfont.font_data = load("res://Fonts/MingLiU-ExtB-01.ttf")
    dfont.size = int(36 * spawn_scale)
    spawn_list.add_font_override("font", dfont)


func _on_spawn_plus() -> void:
    spawn_scale = min(2.5, spawn_scale + 0.2)
    _apply_spawn_scale()


func _on_spawn_minus() -> void:
    spawn_scale = max(0.5, spawn_scale - 0.2)
    _apply_spawn_scale()


func _on_tree_exiting() -> void:
    _cleanup_freecam()
    _cleanup_third_person()
    _cleanup_noclip()


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

    var line1 = "AI:%s  COL:%s  GOD:%s  CAM:%s  TP:%s  NC:%s  TS:%.2fx" % [
        "OFF" if ai_off else "ON",
        "OFF" if col_off else "ON",
        "ON" if god_mode else "OFF",
        "ON" if freecam_on else "OFF",
        "ON" if third_person_on else "OFF",
        "ON" if noclip_on else "OFF",
        Engine.time_scale
    ]
    var line2 = "POS %s   HP %s   ENEMIES %d" % [pos_str, hp_str, enemies]
    hud_label.text = line1 + "\n" + line2


func _cached_enemy_count() -> int:
    cache_frame += 1
    if cache_frame % 30 == 0 or cached_enemies.size() == 0:
        cached_enemies = _find_enemy_roots()
    return cached_enemies.size()
