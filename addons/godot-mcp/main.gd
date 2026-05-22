@tool
extends EditorPlugin

# Godot MCP Plugin - Main script
# This plugin provides Model Context Protocol integration for Godot

const MCP_PORT = 3000
const MCP_HOST = "localhost"

var _mcp_server = null
var _is_active = false

func _enter_tree():
	# Called when the plugin is enabled
	print("Godot MCP Plugin: Initializing...")
	
	# Add your plugin initialization here
	_setup_mcp_server()
	
	# Create menu items or UI elements if needed
	_add_editor_menu_items()

func _exit_tree():
	# Called when the plugin is disabled
	print("Godot MCP Plugin: Shutting down...")
	_stop_mcp_server()

func _has_main_screen():
	return false

func _get_plugin_name():
	return "Godot MCP"

func _setup_mcp_server():
	"""Setup MCP server functionality"""
	# TODO: Implement MCP server setup
	# This would typically involve:
	# 1. Starting a local HTTP/WebSocket server
	# 2. Setting up MCP protocol handlers
	# 3. Registering Godot-specific tools and resources
	
	print("MCP Server would be initialized on port ", MCP_PORT)

func _stop_mcp_server():
	"""Stop MCP server"""
	if _mcp_server:
		_mcp_server.stop()
		_mcp_server = null
	_is_active = false

func _add_editor_menu_items():
	"""Add menu items to the editor"""
	# Create a simple print statement for now
	print("Godot MCP Plugin: Menu items would be added here")

func _start_mcp_server():
	"""Start the MCP server"""
	if not _is_active:
		_setup_mcp_server()
		_is_active = true
		print("MCP Server started successfully")
	else:
		print("MCP Server is already running")

func _stop_mcp_server_menu():
	"""Stop the MCP server from menu"""
	if _is_active:
		_stop_mcp_server()
		print("MCP Server stopped")
	else:
		print("MCP Server is not running")

func _mcp_settings():
	"""Open MCP settings dialog"""
	# TODO: Implement settings dialog
	print("MCP Settings dialog would open here")

func _about_mcp():
	"""Show about dialog"""
	print("Godot MCP Plugin v1.0.0")
	print("This plugin provides Model Context Protocol integration for Godot.")
	print("Author: Coding-Solo")

# Simple menu handler (simplified for tool mode)
func _on_mcp_menu_id_pressed(id):
	print("MCP Menu item selected: ", id)
	match id:
		0:
			_start_mcp_server()
		1:
			_stop_mcp_server_menu()
		2:
			_mcp_settings()
		4:
			_about_mcp()

# Utility functions that could be exposed via MCP
func get_project_info():
	"""Get basic project information"""
	var project_info = {
		"project_name": ProjectSettings.get_setting("application/config/name"),
		"project_path": ProjectSettings.get_setting("application/config/name"),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene"),
		"version": ProjectSettings.get_setting("application/config/version")
	}
	return project_info

func get_scene_tree():
	"""Get the current scene tree structure"""
	var editor_interface = get_editor_interface()
	if editor_interface and editor_interface.get_edited_scene_root():
		return _serialize_node(editor_interface.get_edited_scene_root())
	return null

func _serialize_node(node):
	"""Helper function to serialize a node for MCP"""
	var result = {
		"name": node.name,
		"type": node.get_class(),
		"children": []
	}
	
	for child in node.get_children():
		result["children"].append(_serialize_node(child))
	
	return result
