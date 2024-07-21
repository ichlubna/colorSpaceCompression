# The color profiles need to be made visible by uncommenting STUDIO-Comp-Grading group in PixelManager pack
import bpy
import sys

argv = sys.argv
argv = argv[argv.index("--") + 1:]
profile = argv[0]
imagesPath = argv[1]
outputPath = argv[2]

bpy.context.scene.use_nodes = True
tree = bpy.context.scene.node_tree

for node in tree.nodes:
    tree.nodes.remove(node)

sequenceLength = 100
imageNode = tree.nodes.new(type='CompositorNodeImage')
imageNode.location = 0,0
bpy.ops.image.open(filepath=imagesPath)
imageNode.image = bpy.data.images.values[2]
imageNode.image.colorspace_settings.name = profile
imageNode.image.source = "SEQUENCE"
imageNode.frame_duration = sequenceLength

compositeNode = tree.nodes.new('CompositorNodeComposite')   
compositeNode.location = 1000,0

links = tree.links
link = links.new(imageNode.outputs[0], compositeNode.inputs[0]

bpy.context.scene.frame_end = sequenceLength
bpy.context.scene.render.resolution_y = 3840
bpy.context.scene.render.resolution_x = 2160
bpy.context.scene.render.filepath = outputPath
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.image_settings.color_depth = "16"
bpy.context.scene.render.image_settings.color_mode = "RGB"
bpy.ops.render.render(animation=True, write_still=True)