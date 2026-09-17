"""Start the local Blender MCP server in a separate authoring session."""
import bpy
import blender_mcp

if not hasattr(bpy.types.Scene, "blendermcp_port"):
    blender_mcp.register()
server = blender_mcp.BlenderMCPServer()
server.start()
bpy.context.scene.blendermcp_use_polyhaven = True
