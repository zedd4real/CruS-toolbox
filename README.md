# CruS Toolbox

A debug toolbox for [Cruelty Squad](https://store.steampowered.com/app/1388770/Cruelty_Squad/) — a collection of toggleable helper features for players, modders, and speedrunners.

Requires the [CRUELTY SQUAD MOD LOADER](https://github.com/crustyrashky/crus-modloader).

## Features

| Key | Feature |
|-----|---------|
| F5  | Toggle enemy AI (freeze / unfreeze all enemies) |
| F6  | Toggle enemy collision (walk through enemies) |
| F7  | Remove all NPCs |
| F8  | God mode (best-effort) |
| F9  | Free camera (noclip-style fly) |
| F10 | Third-person camera (mouse wheel zooms) |
| F1  | Teleport to next objective NPC |
| F2 / F3 / F4 | Time scale slower / reset / faster |

A HUD in the top-left corner shows the current state of each feature, plus the player's position / health / enemy count.

## Install

1. Make sure the [Crus Mod Loader](https://github.com/crustyrashky/crus-modloader) is installed.
2. Copy the `CruS Toolbox` folder (containing `mod.json` and `mod.zip`) into:

   `%appdata%\Godot\app_userdata\Cruelty Squad\mods\`

   Final layout:

   ```
   mods\
     CruS Toolbox\
       mod.json
       mod.zip
   ```

3. Launch the game. `logs\mods.log` should show `CruS Toolbox: toolbox spawned`.

## Build (optional)

The `mod.zip` in this repo is pre-built. To rebuild it after editing the source:

```powershell
powershell -ExecutionPolicy Bypass -File package.ps1
```

## Source

- `MOD_CONTENT/CruS Toolbox/init.gd` — bootstraps the toolbox into the scene tree.
- `MOD_CONTENT/CruS Toolbox/toolbox.gd` — the toolbox node (all features + HUD).

## Notes

- Enemy / objective-NPC identification is heuristic (scene filename + the `objective` flag on `EnemyHandler`). Some enemy types may not be detected.
- God mode (F8) keeps the player's `health` topped up each frame; it may not cover every damage source.
