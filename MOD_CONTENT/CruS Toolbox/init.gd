# init.gd — bootstraps the CruS Toolbox into the scene tree.
# The mod loader runs this at startup (see "init" in mod.json).
#
# We must NOT add the toolbox node synchronously from _init(), because init
# scripts run during the mod loader's autoload phase — before the SceneTree is
# "ready". A node added then never gets _ready/_process/_input. So we defer.

extends Node

const TOOLBOX_PATH = "res://MOD_CONTENT/CruS Toolbox/toolbox.gd"


func _init() -> void:
    call_deferred("_spawn")


func _ready() -> void:
    _spawn()


func _spawn() -> void:
    var tree = Engine.get_main_loop()
    if not (tree is SceneTree):
        call_deferred("_spawn")
        return

    var root: Node = tree.root
    if root == null:
        call_deferred("_spawn")
        return

    if root.get_node_or_null("CruSToolbox") != null:
        return

    var script = load(TOOLBOX_PATH)
    if script == null:
        Mod.mod_log("CruS Toolbox: failed to load toolbox script", "CruS Toolbox")
        return

    var node: Node = script.new()
    node.name = "CruSToolbox"
    root.add_child(node)

    Mod.mod_log("CruS Toolbox: toolbox spawned", "CruS Toolbox")
