# The color profiles need to be made visible by uncommenting STUDIO-Comp-Grading group in PixelManager pack
# Also remove S-Log2 ITU 709 Matrix from the inactive spaces list
import bpy
import sys
import os

argv = sys.argv
argv = argv[argv.index("--") + 1:]
profile = argv[0]
imagesPath = argv[1]
outputPath = argv[2]
framesCount = int(argv[3])

bpy.context.scene.use_nodes = True
tree = bpy.context.scene.node_tree
bpy.context.scene.render.compositor_device = "GPU"

for node in tree.nodes:
    tree.nodes.remove(node)

sequenceLength = framesCount
imageNode = tree.nodes.new(type='CompositorNodeImage')
imageNode.location = 0,0
bpy.data.images.load(imagesPath)
image = bpy.data.images[os.path.basename(imagesPath)]
imageNode.image = image
imageNode.image.colorspace_settings.name = profile
if ".mp4" in imagesPath:
    imageNode.image.source = "MOVIE"
else:
    imageNode.image.source = "SEQUENCE"
imageNode.frame_duration = sequenceLength

compositeNode = tree.nodes.new('CompositorNodeComposite')   
compositeNode.location = 1000,0

links = tree.links
link = links.new(imageNode.outputs[0], compositeNode.inputs[0])

bpy.context.scene.frame_end = sequenceLength
bpy.context.scene.render.resolution_x = image.size[0]
bpy.context.scene.render.resolution_y = image.size[1]
bpy.context.scene.render.filepath = outputPath
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.image_settings.color_depth = "16"
bpy.context.scene.render.image_settings.color_mode = "RGB"
bpy.context.scene.display_settings.display_device = "sRGB"
bpy.context.scene.view_settings.view_transform = "None"
bpy.ops.render.render(animation=True, write_still=True)
