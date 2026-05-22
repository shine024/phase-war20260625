# Godot MCP Plugin

Godot Model Context Protocol integration plugin for enhanced editor capabilities.

## Description

This plugin provides Model Context Protocol (MCP) integration for Godot, enabling enhanced communication between Godot editor and external tools. It allows external applications to interact with your Godot project programmatically.

## Features

- **MCP Server Integration**: Start/stop local MCP server for external tool communication
- **Project Information Access**: Get project details, scene tree structure, and resource information
- **Editor Menu Integration**: Easy access through the Godot editor's menu system
- **Extensible Framework**: Base structure for implementing custom MCP tools

## Installation

1. Place this plugin in your Godot project's `addons/` directory
2. The plugin structure should be: `addons/godot-mcp/`
3. Enable the plugin in Project Settings > Plugins
4. Look for the "MCP" menu item in the Godot editor

## Usage

### Enabling the Plugin

1. Open your Godot project
2. Go to Project > Project Settings > Plugins
3. Find "Godot MCP" in the list and enable it
4. The plugin will be active and show messages in the output console

### Current Status

**Note**: This is a basic framework implementation. The plugin includes:
- Proper tool mode configuration
- Basic MCP server structure
- Menu integration framework
- Project information access functions

### Testing the Plugin

1. Enable the plugin in Project Settings
2. Check the Output console for "Godot MCP Plugin: Initializing..." message
3. The plugin is now ready for MCP integration development

### Available Functions

The plugin exposes several utility functions that can be called via MCP:

- `get_project_info()`: Returns project configuration details
- `get_scene_tree()`: Returns the current scene tree structure

### Menu Options

- **Start MCP Server**: Activate the MCP server
- **Stop MCP Server**: Deactivate the MCP server  
- **MCP Settings**: Configure MCP settings (placeholder)
- **About MCP Plugin**: View plugin information

## Configuration

The plugin is configured through the `plugin.cfg` file:

```ini
[plugin]
name="Godot MCP"
description="Godot Model Context Protocol integration plugin for enhanced editor capabilities"
author="Coding-Solo"
version="1.0.0"
script="main.gd"

[dependencies]
godot="4.0"
```

## Development

### File Structure

```
addons/godot-mcp/
├── plugin.cfg          # Plugin configuration
├── main.gd             # Main plugin script
└── README.md          # This file
```

### Customization

You can extend this plugin by:

1. Adding new MCP endpoints in `main.gd`
2. Implementing custom server logic
3. Adding more editor integration features
4. Creating MCP-specific tools and utilities

## Requirements

- Godot 4.0 or later
- MCP-compatible external tools (optional)

## License

This plugin is based on the original work by Coding-Solo. Please refer to the original repository for licensing information.

## Support

For issues and feature requests, please refer to the original repository:
https://github.com/Coding-Solo/godot-mcp

---

**Note**: This is a basic implementation providing the plugin structure and framework. Full MCP server functionality would require additional implementation depending on your specific use case.