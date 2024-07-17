import bpy
import sys

argv = sys.argv
argv = argv[argv.index("--") + 1:]
display = argv[0]
view = argv[1]
bpy.data.scenes["Scene"].display_settings.display_device = display
bpy.data.scenes["Scene"].view_settings.view_transform = view
bpy.data.scenes["Scene"].render.image_settings.file_format = "OPEN_EXR"
bpy.data.scenes["Scene"].render.image_settings.color_mode = "RGB"
bpy.data.scenes["Scene"].render.image_settings.color_depth = 32
bpy.data.scenes["Scene"].render.resolution_x = 3840
bpy.data.scenes["Scene"].render.resolution_y = 2160
