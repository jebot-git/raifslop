import bpy
import sys
sys.path.insert(0, '/home/blux/.config/blender/5.2/scripts/addons')
import blender_mcp
if not hasattr(bpy.types.Scene, 'blendermcp_port'):
    blender_mcp.register()
if not hasattr(bpy.types, 'blendermcp_server'):
    bpy.ops.blendermcp.start_server()
