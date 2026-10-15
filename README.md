# CruS Toolbox · CruS 工具箱

A debug toolbox for [Cruelty Squad](https://store.steampowered.com/app/1388770/Cruelty_Squad/) — a collection of toggleable helper features for players, modders, and speedrunners.

一个 [Cruelty Squad](https://store.steampowered.com/app/1388770/Cruelty_Squad/) 的调试工具箱 —— 一系列可开关的辅助功能，面向玩家、mod 作者和速通玩家。

Requires the [CRUELTY SQUAD MOD LOADER](https://github.com/crustyrashky/crus-modloader) · 需要 [Crus Mod Loader](https://github.com/crustyrashky/crus-modloader)。

## Features · 功能

| Key · 热键 | Feature · 功能 |
|-----------|----------------|
| F5 | Toggle enemy AI · 敌人 AI 开关（冻结/恢复所有敌人） |
| F6 | Toggle enemy collision · 敌人碰撞开关（穿人） |
| F7 | Remove all NPCs · 移除所有 NPC |
| F8 | God mode · 无敌模式 |
| F9 | Free camera · 自由相机（noclip 式飞行） |
| F10 | Third-person camera · 第三人称（滚轮缩放） |
| F1 | Teleport to next objective NPC · 传送到目标 NPC |
| F2 / F3 / F4 | Time scale slower / reset / faster · 时间缩放（慢 / 重置 / 快） |

A HUD in the top-left corner shows the current state of each feature, plus the player's position / health / enemy count.

左上角的 HUD 显示每个功能的当前状态，以及玩家位置 / 血量 / 敌人数量。

## Install · 安装

1. Make sure the [Crus Mod Loader](https://github.com/crustyrashky/crus-modloader) is installed. · 确保已安装 [Crus Mod Loader](https://github.com/crustyrashky/crus-modloader)。
2. Copy the `CruS Toolbox` folder (containing `mod.json` and `mod.zip`) into · 把 `CruS Toolbox` 文件夹（含 `mod.json` 和 `mod.zip`）复制到：

   `%appdata%\Godot\app_userdata\Cruelty Squad\mods\`

   Final layout · 最终结构：

   ```
   mods\
     CruS Toolbox\
       mod.json
       mod.zip
   ```

3. Launch the game. `logs\mods.log` should show `CruS Toolbox: toolbox spawned`. · 启动游戏，`logs\mods.log` 里应出现 `CruS Toolbox: toolbox spawned`。

## Build · 构建（可选）

The `mod.zip` in this repo is pre-built. To rebuild it after editing the source · 仓库里的 `mod.zip` 是预构建好的。改完源码后要重新构建：

```powershell
powershell -ExecutionPolicy Bypass -File package.ps1
```

## Source · 源码

- `MOD_CONTENT/CruS Toolbox/init.gd` — bootstraps the toolbox into the scene tree · 把工具箱挂进场景树。
- `MOD_CONTENT/CruS Toolbox/toolbox.gd` — the toolbox node (all features + HUD) · 工具箱主节点（所有功能 + HUD）。

## Notes · 说明

- Enemy / objective-NPC identification is heuristic (scene filename + the `objective` flag on `EnemyHandler`). Some enemy types may not be detected. · 敌人 / 目标 NPC 的识别是启发式的（场景文件名 + `EnemyHandler` 上的 `objective` 标志），部分敌人类型可能识别不到。
- God mode (F8) keeps the player's `health` topped up each frame; it may not cover every damage source. · 无敌（F8）每帧把玩家血量顶满，不一定覆盖所有伤害来源。
