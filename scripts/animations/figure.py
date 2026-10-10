"""Builds build/animations/figure.blend: MPFB's CC0 base human with its Rigify rig, dressed in the one committed
CC0 clothing asset (assets/male_casualsuit04, from MakeHuman's system asset pack). Only this step needs MPFB.

Run by render.py when the .blend is missing:
    blender --background --factory-startup --python-exit-code 1 --python scripts/animations/figure.py
"""
import os
import sys

import addon_utils
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "build", "animations", "figure.blend")
CLOTHES = os.path.join(HERE, "assets", "male_casualsuit04", "male_casualsuit04.mhclo")

bpy.ops.wm.read_factory_settings(use_empty=True)
# --factory-startup doesn't load user extensions, so enable them for this session only.
addon_utils.enable("rigify", default_set=True, persistent=False)
addon_utils.enable("bl_ext.user_default.mpfb", default_set=True, persistent=False)
try:
    from bl_ext.user_default.mpfb.services.humanservice import HumanService
    from bl_ext.user_default.mpfb.services.rigservice import RigService
except ImportError:
    sys.exit("MPFB 2.0.17 isn't installed in Blender 5.2; see README.md, Rendering exercise animations.")

base = HumanService.create_human()  # its default scale, 0.1, gives metres
meta = HumanService.add_builtin_rig(base, "rigify.human_toes")
HumanService.add_mhclo_asset(CLOTHES, base, asset_type="Clothes", material_type="MAKESKIN")
rig = RigService.generate_rigify_rig(meta, meta_rig_action="delete")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("FIGURE", OUT, rig.name, [o.name for o in rig.children])
