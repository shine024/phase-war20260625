# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 48 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.5.1
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Local Godot CLI (this machine)

Godot is **not** assumed to be on `PATH`. When running checks or headless commands from the repo root, use this executable (update here if you move or upgrade Godot):

- **Windows**: `E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe`  
  若本机 Vulkan 有问题，可加 `--rendering-driver opengl3`（对 `--headless` / `--check-only` 也适用）。

Example (PowerShell, project folder = this repo):

```powershell
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --path "." --version
```

项目校验（无 UI，推荐）：

```powershell
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --check-only
```

蓝图 v3 经济 + `UnitStatsTable` 时代缩放烟测（无 GdUnit 依赖）：

```powershell
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/star_config_smoke.gd"
```

GdUnit 全量单测（`tests/gdunit4_runner.gd` 会注入 `-a res://tests/unit` 等参数）：

```powershell
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/gdunit4_runner.gd"
```

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
