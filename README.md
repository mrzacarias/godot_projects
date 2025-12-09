# Godot Projects

This repository contains several Godot game projects with automated build and deployment scripts.

## Games

### 2d-dodge-the-creeps
- **Itch.io URL**: https://zacasoft.itch.io/dodge-the-creeps
- **Build Script**: `2d-dodge-the-creeps/pack_and_deploy.sh`
- **Archive Name**: `dodge-the-creeps-html.zip`

### vamlike-survivors
- **Itch.io URL**: https://zacasoft.itch.io/vamlike-survivors
- **Build Script**: `vamlike-survivors/pack_and_deploy.sh`
- **Archive Name**: `vamlike-survivors-html.zip`

### survive-30-days
- **Itch.io URL**: https://zacasoft.itch.io/survive-30-days
- **Build Script**: `survive-30-days/pack_and_deploy.sh`
- **Archive Name**: `survive-30-days-html.zip`

## Usage

Each game has its own `pack_and_deploy.sh` script that:

1. **Exports** the Godot project to HTML5/WebAssembly format
2. **Creates** a compressed archive of the build
3. **Deploys** to itch.io using butler (if available)

### Prerequisites

- **Godot 4**: Installed at `/Applications/Godot.app/Contents/MacOS/Godot`
- **Butler**: Install with `brew install butler` or from https://itch.io/docs/butler/

### Running a Build

Navigate to any game directory and run:

```bash
cd 2d-dodge-the-creeps
./pack_and_deploy.sh
```

### Safety Features

- **No Overwriting**: Scripts use existing `html/` directories and won't overwrite them
- **Unique Archives**: Each game creates its own uniquely named zip file
- **Error Handling**: Scripts exit on any error and provide detailed logs
- **Butler Check**: Gracefully handles missing butler installation

### Archive Locations

Archives are created in each game's root directory:
- `2d-dodge-the-creeps/dodge-the-creeps-html.zip`
- `vamlike-survivors/vamlike-survivors-html.zip`
- `survive-30-days/survive-30-days-html.zip`

These archives can be manually uploaded to itch.io if butler is not available.
