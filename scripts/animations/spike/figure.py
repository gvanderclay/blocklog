import bpy, addon_utils, time, sys, os
t0=time.time()
bpy.ops.wm.read_factory_settings(use_empty=True)
addon_utils.enable("rigify", default_set=True, persistent=False)
addon_utils.enable("bl_ext.user_default.mpfb", default_set=True, persistent=False)
from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.rigservice import RigService
A="/tmp/blspike/assets/clothes/"
CLOTHES=sys.argv[sys.argv.index("--")+1:] or ["male_casualsuit01"]
bm=HumanService.create_human()
print("basemesh dims", tuple(bm.dimensions))
meta=HumanService.add_builtin_rig(bm,"rigify.human_toes")
print("metarig", meta.name, len(meta.data.bones))
for c in CLOTHES:
    HumanService.add_mhclo_asset(A+f"{c}/{c}.mhclo", bm, asset_type="Clothes", material_type="MAKESKIN")
rig=RigService.generate_rigify_rig(meta, meta_rig_action="delete")
print("rig", rig.name, len(rig.data.bones), "children", [o.name for o in rig.children])
bpy.ops.wm.save_as_mainfile(filepath=f"/tmp/blspike/figure_{CLOTHES[0]}.blend")
print("FIGURE_SECONDS", round(time.time()-t0,2))
