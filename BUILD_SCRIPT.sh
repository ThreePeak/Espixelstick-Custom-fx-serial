#!/bin/bash

# ESPixelStick Enhanced - Build Script
# This script automates the build process for the enhanced ESPixelStick firmware

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
BOARD="d1_mini"
CLEAN_BUILD=false
UPLOAD=false
UPLOAD_FS=false
MONITOR=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show help
show_help() {
    echo "ESPixelStick Enhanced - Build Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -b, --board BOARD       Target board (default: d1_mini)"
    echo "  -c, --clean              Clean build before compiling"
    echo "  -u, --upload             Upload firmware after build"
    echo "  -f, --upload-fs          Upload filesystem after build"
    echo "  -m, --monitor            Start serial monitor after operations"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Supported boards:"
    echo "  d1_mini, d1_mini_pro, espsv3 (ESP8266)"
    echo "  d1_mini32, d32_pro, esp32_cam (ESP32)"
    echo ""
    echo "Examples:"
    echo "  $0 -b espsv3 -c -u -f"
    echo "  $0 --board d1_mini32 --clean --upload --monitor"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--board)
            BOARD="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -u|--upload)
            UPLOAD=true
            shift
            ;;
        -f|--upload-fs)
            UPLOAD_FS=true
            shift
            ;;
        -m|--monitor)
            MONITOR=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if PlatformIO is installed
if ! command -v pio &> /dev/null; then
    print_error "PlatformIO is not installed. Please install it with:"
    print_error "pip install platformio"
    exit 1
fi

# Check if we're in the correct directory
if [[ ! -f "platformio.ini" ]]; then
    print_error "platformio.ini not found. Please run this script from the ESPixelStick root directory."
    exit 1
fi

# Verify the board is supported
SUPPORTED_BOARDS=("d1_mini" "d1_mini_pro" "espsv3" "esp01s" "d1_mini32" "d32_pro" "esp32_cam")
if [[ ! " ${SUPPORTED_BOARDS[@]} " =~ " ${BOARD} " ]]; then
    print_error "Unsupported board: $BOARD"
    print_error "Supported boards: ${SUPPORTED_BOARDS[*]}"
    exit 1
fi

print_status "Starting build for board: $BOARD"

# Check if required files exist
REQUIRED_FILES=(
    "src/main.cpp"
    "src/SerialConsole.hpp"
    "src/SerialConsole.cpp"
    "src/LEDEffects.hpp"
    "src/LEDEffects.cpp"
    "src/WebMgr.cpp"
    "html/console.html"
    "html/effects_enhanced.html"
    "html/index.html"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        print_error "Required file not found: $file"
        exit 1
    fi
done

print_success "All required files found"

# Prepare data directory for filesystem
print_status "Preparing filesystem data..."
mkdir -p data/www
cp html/*.html data/www/ 2>/dev/null || true
cp html/css/*.css data/www/ 2>/dev/null || true
cp html/js/*.js data/www/ 2>/dev/null || true

if [[ -d "data/www" ]] && [[ $(ls -A data/www) ]]; then
    print_success "Filesystem data prepared"
else
    print_warning "No filesystem data found - web interfaces may not work"
fi

# Clean build if requested
if [[ "$CLEAN_BUILD" == "true" ]]; then
    print_status "Cleaning previous build..."
    pio run -e "$BOARD" --target clean
    print_success "Build cleaned"
fi

# Build the firmware
print_status "Building firmware for $BOARD..."
if pio run -e "$BOARD"; then
    print_success "Firmware built successfully"
else
    print_error "Build failed"
    exit 1
fi

# Build filesystem if data exists
if [[ -d "data/www" ]] && [[ $(ls -A data/www) ]]; then
    print_status "Building filesystem..."
    if pio run -e "$BOARD" --target buildfs; then
        print_success "Filesystem built successfully"
    else
        print_error "Filesystem build failed"
        exit 1
    fi
fi

# Upload firmware if requested
if [[ "$UPLOAD" == "true" ]]; then
    print_status "Uploading firmware..."
    if pio run -e "$BOARD" --target upload; then
        print_success "Firmware uploaded successfully"
    else
        print_error "Firmware upload failed"
        exit 1
    fi
fi

# Upload filesystem if requested
if [[ "$UPLOAD_FS" == "true" ]] && [[ -d "data/www" ]] && [[ $(ls -A data/www) ]]; then
    print_status "Uploading filesystem..."
    if pio run -e "$BOARD" --target uploadfs; then
        print_success "Filesystem uploaded successfully"
    else
        print_error "Filesystem upload failed"
        exit 1
    fi
fi

# Start monitor if requested
if [[ "$MONITOR" == "true" ]]; then
    print_status "Starting serial monitor (Press Ctrl+C to exit)..."
    pio device monitor -b 115200
fi

# Show next steps
print_status "Build completed successfully!"
echo ""
echo "Next steps:"
if [[ "$UPLOAD" != "true" ]]; then
    echo "1. Upload firmware:    pio run -e $BOARD --target upload"
fi
if [[ "$UPLOAD_FS" != "true" ]] && [[ -d "data/www" ]]; then
    echo "2. Upload filesystem:  pio run -e $BOARD --target uploadfs"
fi
echo "3. Start monitor:       pio device monitor -b 115200"
echo ""
echo "After uploading:"
echo "- Access web interface at http://[DEVICE_IP]/"
echo "- Access serial console at http://[DEVICE_IP]/console"
echo "- Access enhanced effects at http://[DEVICE_IP]/effects_enhanced.html"
echo "- Test API with: curl http://[DEVICE_IP]/api/effects"

print_success "ESPixelStick Enhanced build complete!"