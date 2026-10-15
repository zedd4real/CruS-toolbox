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

---

# CruS 工具箱

一个 [Cruelty Squad](https://store.steampowered.com/app/1388770/Cruelty_Squad/) 的调试工具箱 —— 一系列可开关的辅助功能，面向玩家、mod 作者和速通玩家。

需要 [Crus Mod Loader](https://github.com/crustyrashky/crus-modloader)。

## 功能

| 热键 | 功能 |
|------|------|
| F5 | 敌人 AI 开关（冻结/恢复所有敌人） |
| F6 | 敌人碰撞开关（穿人） |
| F7 | 移除所有 NPC |
| F8 | 无敌模式 |
| F9 | 自由相机（noclip 式飞行） |
| F10 | 第三人称（滚轮缩放） |
| F1 | 传送到目标 NPC |
| F2 / F3 / F4 | 时间缩放（慢 / 重置 / 快） |

左上角的 HUD 显示每个功能的当前状态，以及玩家位置 / 血量 / 敌人数量。

## 安装

1. 确保已安装 [Crus Mod Loader](https://github.com/crustyrashky/crus-modloader)。
2. 把 `CruS Toolbox` 文件夹（含 `mod.json` 和 `mod.zip`）复制到：

   `%appdata%\Godot\app_userdata\Cruelty Squad\mods\`

   最终结构：

   ```
   mods\
     CruS Toolbox\
       mod.json
       mod.zip
   ```

3. 启动游戏，`logs\mods.log` 里应出现 `CruS Toolbox: toolbox spawned`。

## 构建（可选）

仓库里的 `mod.zip` 是预构建好的。改完源码后要重新构建：

```powershell
powershell -ExecutionPolicy Bypass -File package.ps1
```

## 源码

- `MOD_CONTENT/CruS Toolbox/init.gd` —— 把工具箱挂进场景树。
- `MOD_CONTENT/CruS Toolbox/toolbox.gd` —— 工具箱主节点（所有功能 + HUD）。

## 说明

- 敌人 / 目标 NPC 的识别是启发式的（场景文件名 + `EnemyHandler` 上的 `objective` 标志），部分敌人类型可能识别不到。
- 无敌（F8）每帧把玩家血量顶满，不一定覆盖所有伤害来源。
