"""
Headless Blender script: bakes rupert.glb into an 8-direction, 6-frame walk
cycle sprite sheet for the Godot top-down game.

Run with:
  "C:\\Program Files\\Blender Foundation\\Blender 4.3\\blender.exe" \\
      --background --python tools/bake_rupert_sheet.py

Output: assets/rupert_sheet.png  (1024 x 768, 8 cols x 6 rows, 128px frames)

Tunables live at the top of the file. The "walk cycle" is faked via
whole-body bob + tilt — no rig required, works on raw scans.
"""

import bpy
import math
import os
import subprocess
import sys
from mathutils import Vector

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PROJECT_ROOT   = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOURCE_GLB     = os.path.join(PROJECT_ROOT, "rupert.glb")
FRAME_OUT_DIR  = os.path.join(PROJECT_ROOT, "build", "rupert_frames")
FINAL_SHEET    = os.path.join(PROJECT_ROOT, "assets", "rupert_sheet.png")

FRAME_SIZE     = 128            # per-frame pixel size
NUM_DIRECTIONS = 8              # 0=E, 1=SE, ... 7=NE (CW around top-down)
FRAMES_PER_DIR = 6              # walk cycle length
CAM_ELEVATION_DEG = 58.0        # Hades-ish 3/4 top-down. 90 = pure top-down.
CAM_DISTANCE_MULT = 3.0         # multiplied by mesh bounding radius
ORTHO_PADDING     = 1.15        # extra ortho zoom-out so legs don't clip

# Walk cycle tuning (fake — no skeleton needed)
WALK_BOB_HEIGHT   = 0.07        # Z-axis hop, fraction of bear height
WALK_TILT_DEG     = 5.5         # side tilt at peak of step
WALK_SQUASH       = 0.04        # vertical squash on foot-plant frames

# Mesh orientation correction. Scans come in any orientation. These rotate
# the mesh BEFORE normalization so we can stand the bear upright and face
# him toward +Y (which is what the camera looks down at when direction=0).
# Override from CLI: blender ... -- --rx 90 --ry 0 --rz 180
ROTATE_X_DEG = 0.0
ROTATE_Y_DEG = 0.0
ROTATE_Z_DEG = 0.0

# Preview mode: render one big front frame to assets/rupert_preview.png and
# skip the 48-frame bake. Use to dial orientation before committing.
PREVIEW_MODE = False
PREVIEW_SIZE = 512

# Lighting strength multiplier (scans often render dark)
LIGHT_MULT = 2.0

# ---------------------------------------------------------------------------
# Scene setup
# ---------------------------------------------------------------------------

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):     bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):  bpy.data.materials.remove(block)
    for block in list(bpy.data.images):     bpy.data.images.remove(block)
    for block in list(bpy.data.cameras):    bpy.data.cameras.remove(block)
    for block in list(bpy.data.lights):     bpy.data.lights.remove(block)


def import_rupert():
    bpy.ops.import_scene.gltf(filepath=SOURCE_GLB)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        sys.exit("ERROR: no mesh objects found in rupert.glb")
    # Join all imported meshes into one for easier handling
    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    bear = bpy.context.active_object
    bear.name = "Rupert"
    return bear


def keep_largest_island(bear):
    """Scans typically leave background fragments as separate vertex islands.
    Split by loose parts, keep only the chunk with the most polygons, delete
    the rest. Returns the surviving object (still named after the original)."""
    bpy.context.view_layer.objects.active = bear
    bpy.ops.object.select_all(action="DESELECT")
    bear.select_set(True)
    # Enter edit mode, select all, separate by loose parts → multiple objects
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    if len(parts) <= 1:
        print(f"[rupert] mesh already single-island ({len(parts)} parts)")
        return bear
    # Sort by polygon count
    parts.sort(key=lambda o: len(o.data.polygons), reverse=True)
    max_poly = len(parts[0].data.polygons)
    # Keep every island that's at least 2% of the largest — Rupert's body is
    # usually split into ear/head/limb shells that aren't fully welded; we
    # want all of them, just not the background flecks.
    threshold = max(max_poly * 0.02, 50)
    keepers = [p for p in parts if len(p.data.polygons) >= threshold]
    drops   = [p for p in parts if p not in keepers]
    print(f"[rupert] keeping {len(keepers)} islands "
          f"(>= {int(threshold)} polys), dropping {len(drops)}")
    # Delete the junk
    bpy.ops.object.select_all(action="DESELECT")
    for d in drops:
        d.select_set(True)
    if drops:
        bpy.ops.object.delete(use_global=False)
    # Re-join the keepers into one mesh so downstream code (normalize,
    # decimate, transform) operates on a single object.
    bpy.ops.object.select_all(action="DESELECT")
    for k in keepers:
        k.select_set(True)
    bpy.context.view_layer.objects.active = keepers[0]
    if len(keepers) > 1:
        bpy.ops.object.join()
    rejoined = bpy.context.active_object
    rejoined.name = "Rupert"
    return rejoined


def normalize_bear(bear):
    """Center on world origin, rest on Z=0, normalize to height = 1.0."""
    bear = keep_largest_island(bear)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Bounding box in world space
    bbox = [bear.matrix_world @ Vector(c) for c in bear.bound_box]
    xs = [v.x for v in bbox]; ys = [v.y for v in bbox]; zs = [v.z for v in bbox]
    cx = (min(xs) + max(xs)) / 2.0
    cy = (min(ys) + max(ys)) / 2.0
    zmin = min(zs)
    height = max(zs) - zmin
    if height <= 0:
        sys.exit("ERROR: degenerate mesh, zero height")
    # Move to origin, rest on floor
    bear.location.x -= cx
    bear.location.y -= cy
    bear.location.z -= zmin
    bpy.ops.object.transform_apply(location=True)
    # Scale to unit height
    s = 1.0 / height
    bear.scale = (s, s, s)
    bpy.ops.object.transform_apply(scale=True)
    # Optional orientation correction (rotate mesh in place, then re-floor)
    if ROTATE_X_DEG or ROTATE_Y_DEG or ROTATE_Z_DEG:
        bear.rotation_euler = (
            math.radians(ROTATE_X_DEG),
            math.radians(ROTATE_Y_DEG),
            math.radians(ROTATE_Z_DEG),
        )
        bpy.ops.object.transform_apply(rotation=True)
        # Re-floor after rotation: bbox may have moved below Z=0
        bbox2 = [bear.matrix_world @ Vector(c) for c in bear.bound_box]
        zs2 = [v.z for v in bbox2]
        xs2 = [v.x for v in bbox2]; ys2 = [v.y for v in bbox2]
        bear.location.x -= (min(xs2) + max(xs2)) / 2.0
        bear.location.y -= (min(ys2) + max(ys2)) / 2.0
        bear.location.z -= min(zs2)
        bpy.ops.object.transform_apply(location=True)
    # Decimate
    dec = bear.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = 0.15  # ~85% reduction; scans are way over budget
    bpy.ops.object.modifier_apply(modifier="Decimate")
    return bear


def setup_camera_and_lights():
    # Orthographic camera, parented to an empty so we can spin it for angles
    pivot = bpy.data.objects.new("Pivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.location = (0, 0, 0.5)  # bear midpoint

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 1.2 * ORTHO_PADDING
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.parent = pivot
    # Position camera along +Y at the given elevation
    elev = math.radians(CAM_ELEVATION_DEG)
    d = CAM_DISTANCE_MULT
    cam.location = (0, -d * math.cos(elev), d * math.sin(elev))
    # Aim camera at pivot
    track = cam.constraints.new("TRACK_TO")
    track.target = pivot
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"

    bpy.context.scene.camera = cam

    # Three-point lighting
    def add_light(name, loc, energy, color=(1, 1, 1)):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = energy
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        bpy.context.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = (math.radians(60), 0, math.radians(45))
        return lo
    add_light("Key",  ( 2,  2, 3), 5.0 * LIGHT_MULT)
    add_light("Fill", (-2,  1, 2), 2.5 * LIGHT_MULT, (0.85, 0.9, 1.0))
    add_light("Rim",  ( 0, -2, 2.5), 3.5 * LIGHT_MULT, (1.0, 0.95, 0.85))
    # Ambient world boost so the underside isn't pure black
    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[1].default_value = 0.8  # strength

    return pivot


def setup_render():
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(s, "eevee") and \
        "BLENDER_EEVEE_NEXT" in [e.identifier for e in
        bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] \
        else "BLENDER_EEVEE"
    s.render.resolution_x = FRAME_SIZE
    s.render.resolution_y = FRAME_SIZE
    s.render.resolution_percentage = 100
    s.render.film_transparent = True
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    s.render.image_settings.compression = 15
    # Quick + clean
    if hasattr(s, "eevee"):
        s.eevee.taa_render_samples = 32


# ---------------------------------------------------------------------------
# Walk cycle (no rig — whole-body transforms)
# ---------------------------------------------------------------------------

def apply_walk_pose(bear, frame_idx):
    """frame_idx in [0, FRAMES_PER_DIR). Pure cosmetic bob/tilt."""
    t = frame_idx / float(FRAMES_PER_DIR)
    # 2 steps per cycle (left foot, right foot)
    step_phase = math.sin(t * math.tau * 2.0)            # -1..1
    bob = abs(step_phase) * WALK_BOB_HEIGHT               # 0..bob — only up
    tilt = step_phase * math.radians(WALK_TILT_DEG)      # alternating side
    squash = 1.0 - (1.0 - abs(step_phase)) * WALK_SQUASH  # squash on plant
    bear.location.z = bob
    bear.rotation_euler = (0, tilt, 0)  # tilt around forward (Y)
    bear.scale = (1.0, 1.0, squash)


def render_all(bear, pivot):
    os.makedirs(FRAME_OUT_DIR, exist_ok=True)
    for d in range(NUM_DIRECTIONS):
        # 0=E (+X), 1=SE, 2=S (-Y), 3=SW, 4=W (-X), 5=NW, 6=N (+Y), 7=NE
        # Pivot rotation around Z spins the camera around the bear.
        # We want to view from the angle so the bear's "facing east" appears
        # head-on when direction=0.
        angle_deg = -d * (360.0 / NUM_DIRECTIONS)  # negative = CW
        pivot.rotation_euler.z = math.radians(angle_deg)
        for f in range(FRAMES_PER_DIR):
            apply_walk_pose(bear, f)
            bpy.context.view_layer.update()
            out = os.path.join(FRAME_OUT_DIR, f"dir{d}_f{f}.png")
            bpy.context.scene.render.filepath = out
            bpy.ops.render.render(write_still=True)
            print(f"[rupert] rendered dir{d} frame{f} -> {out}")


# ---------------------------------------------------------------------------
# Sprite-sheet packing (via Pillow, falling back to bundled libs)
# ---------------------------------------------------------------------------

def pack_sheet():
    """Combine all rendered frames into one PNG: 8 cols x 6 rows."""
    try:
        from PIL import Image
    except ImportError:
        # Blender's bundled python ships without PIL — install it on the fly
        py = sys.executable
        subprocess.check_call([py, "-m", "ensurepip"])
        subprocess.check_call([py, "-m", "pip", "install", "--quiet", "Pillow"])
        from PIL import Image

    sheet = Image.new("RGBA",
        (FRAME_SIZE * NUM_DIRECTIONS, FRAME_SIZE * FRAMES_PER_DIR),
        (0, 0, 0, 0))
    for d in range(NUM_DIRECTIONS):
        for f in range(FRAMES_PER_DIR):
            p = os.path.join(FRAME_OUT_DIR, f"dir{d}_f{f}.png")
            im = Image.open(p).convert("RGBA")
            sheet.paste(im, (d * FRAME_SIZE, f * FRAME_SIZE))
    os.makedirs(os.path.dirname(FINAL_SHEET), exist_ok=True)
    sheet.save(FINAL_SHEET, optimize=True)
    print(f"[rupert] sprite sheet written: {FINAL_SHEET}  "
          f"({sheet.width}x{sheet.height})")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_cli_args():
    """Read --rx --ry --rz --preview from argv (after Blender's `--`)."""
    global ROTATE_X_DEG, ROTATE_Y_DEG, ROTATE_Z_DEG, PREVIEW_MODE
    if "--" not in sys.argv:
        return
    args = sys.argv[sys.argv.index("--") + 1:]
    i = 0
    while i < len(args):
        if args[i] == "--rx":
            ROTATE_X_DEG = float(args[i + 1]); i += 2
        elif args[i] == "--ry":
            ROTATE_Y_DEG = float(args[i + 1]); i += 2
        elif args[i] == "--rz":
            ROTATE_Z_DEG = float(args[i + 1]); i += 2
        elif args[i] == "--preview":
            PREVIEW_MODE = True; i += 1
        else:
            i += 1
    print(f"[rupert] rot=({ROTATE_X_DEG},{ROTATE_Y_DEG},{ROTATE_Z_DEG}) "
          f"preview={PREVIEW_MODE}")


def render_preview(bear, pivot):
    """One big front-on render. Lets you eyeball orientation fast."""
    out = os.path.join(PROJECT_ROOT, "assets", "rupert_preview.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    s = bpy.context.scene
    s.render.resolution_x = PREVIEW_SIZE
    s.render.resolution_y = PREVIEW_SIZE
    pivot.rotation_euler.z = 0.0
    apply_walk_pose(bear, 0)
    bpy.context.view_layer.update()
    s.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print(f"[rupert] preview: {out}")


def main():
    parse_cli_args()
    if not os.path.isfile(SOURCE_GLB):
        sys.exit(f"ERROR: missing {SOURCE_GLB}")
    clear_scene()
    bear = import_rupert()
    bear = normalize_bear(bear)
    pivot = setup_camera_and_lights()
    setup_render()
    if PREVIEW_MODE:
        render_preview(bear, pivot)
    else:
        render_all(bear, pivot)
        pack_sheet()
    print("[rupert] DONE")


if __name__ == "__main__":
    main()
