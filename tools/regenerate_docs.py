"""Regenerate exported Markdown/CSV under docs/ from data/*.gd sources."""
from pathlib import Path

import export_blueprint_enemy_docs
import export_enemy_archetype_list


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    export_enemy_archetype_list.main()
    export_blueprint_enemy_docs.main()
    print(f"Done. Outputs in {root / 'docs'}")


if __name__ == "__main__":
    main()
