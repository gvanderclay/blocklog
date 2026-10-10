"""Writes App/Resources/exercise-animations.json from every pose file in scripts/animations/exercises.
Run with the system python3 (no Blender): `python3 scripts/animations/manifest.py`; `just animate` runs it."""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
EXERCISES = os.path.join(HERE, "exercises")
OUT = os.path.join(ROOT, "App", "Resources", "exercise-animations.json")

entries = []
for name in sorted(os.listdir(EXERCISES)):
    if name.endswith(".json"):
        spec = json.load(open(os.path.join(EXERCISES, name)))
        entries.append({"exercise": spec["exercise"], "file": name[:-5], "description": spec["description"]})
with open(OUT, "w") as f:
    json.dump(entries, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"MANIFEST {OUT}: {len(entries)} animations")
