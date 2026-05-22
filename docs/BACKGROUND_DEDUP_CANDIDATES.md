# Background Dedup Candidates (Draft)

This is a read-only audit draft for background texture cleanup.  
No files are removed in this step.

## Scope

- Folder: `assets/backgrounds`
- Naming families observed:
  - `bg_level_1.png` ... `bg_level_8.png`
  - `bg_level_01.png` ... `bg_level_08.png`

## Reference audit result

- Runtime code uses padded convention:
  - `scenes/battlefield/Battlefield.gd`
  - `LEVEL_BG_PATH_FMT := "res://assets/backgrounds/bg_level_%02d.png"`
  - `COMMON_BATTLE_BG_PATH := "res://assets/backgrounds/bg_level_01.png"`
- No runtime code/scene references to `bg_level_1.png` ... `bg_level_8.png` were found.

## Hash check result (1..8 pairs)

SHA-256 comparison confirms these are **not identical same-index pairs**:

- `bg_level_1.png` != `bg_level_01.png`
- `bg_level_2.png` != `bg_level_02.png`
- `bg_level_3.png` != `bg_level_03.png`
- `bg_level_4.png` != `bg_level_04.png`
- `bg_level_5.png` != `bg_level_05.png`
- `bg_level_6.png` != `bg_level_06.png`
- `bg_level_7.png` != `bg_level_07.png`
- `bg_level_8.png` != `bg_level_08.png`

Additional observation: non-padded files appear to form a shifted chain against padded files (for example, `bg_level_3.png` hash equals `bg_level_02.png` hash), suggesting legacy export/migration artifacts.

## Cleanup candidates (safe-first)

Given zero runtime references to the non-padded family, these are the primary cleanup candidates:

- `bg_level_1.png` ... `bg_level_8.png`
- Their matching `.import` files

## Suggested safe workflow

1. Build a usage map with code/scene references for both naming families.
2. Keep padded naming as canonical (`bg_level_%02d.png`) because runtime loader already depends on it.
3. Redirect references from deprecated filenames to canonical filenames.
4. Run a full scene load smoke test and one battle entry test.
5. Delete deprecated files only after reference count for deprecated names is zero.

## Expected impact

- Fewer accidental duplicate imports for near-identical assets.
- Cleaner maintenance for level-background mapping logic.
- Reduced risk of inconsistent import settings across duplicated files.
