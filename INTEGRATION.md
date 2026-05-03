# OCR Desktop Application - Integration Guide

## Project Structure

```
Swift-Python-C-OCR-/
├── cpp/                          # C++ Image Preprocessing Library
│   ├── CMakeLists.txt
│   ├── image_processor.h
│   └── image_processor.cpp
├── python/                       # Python OCR Service
│   ├── ocr_service.py
│   ├── requirements.txt
│   └── lib/                      # Compiled C++ library
├── swift/                        # Swift AppKit Application
│   ├── project.yml
│   └── OCRApp/
│       ├── main.swift
│       ├── AppDelegate.swift
│       ├── MainWindowController.swift
│       ├── MainViewController.swift
│       ├── DragDropView.swift
│       ├── ScreenCaptureWindow.swift
│       ├── OCRService.swift
│       ├── HistoryManager.swift
│       └── Info.plist
└── README.md
```

## Prerequisites

### C++ Library
- CMake 3.10 or higher
- C++ compiler (g++, clang++, or MSVC)

### Python Service
- Python 3.8 or higher
- pip package manager
- Tesseract OCR engine

### Swift Application
- Xcode 15 or higher
- macOS 11.0 or higher
- XcodeGen (for project generation)

## Build Instructions

### 1. Build C++ Library

**macOS/Linux:**
```bash
cd cpp
mkdir build && cd build
cmake ..
make
```

**Windows:**
```bash
cd cpp
mkdir build && cd build
cmake ..
cmake --build . --config Release
```

The compiled library will be placed in `python/lib/`:
- macOS: `libimage_processor.dylib`
- Linux: `libimage_processor.so`
- Windows: `image_processor.pyd`

### 2. Install Python Dependencies

```bash
cd python
pip install -r requirements.txt
```

**Important:** Install Tesseract OCR on your system:

**macOS:**
```bash
brew install tesseract
brew install tesseract-lang  # For Chinese language support
```

**Ubuntu/Debian:**
```bash
sudo apt-get install tesseract-ocr
sudo apt-get install tesseract-ocr-chi-sim  # Chinese support
```

**Windows:**
Download Tesseract from: https://github.com/UB-Mannheim/tesseract/wiki

### 3. Generate Xcode Project and Build Swift App

```bash
cd swift
xcodegen generate
xcodebuild -project OCRApp.xcodeproj -scheme OCRApp -configuration Release build
```

Or open `OCRApp.xcodeproj` in Xcode and build.

### 4. Start Python OCR Service

```bash
cd python
python ocr_service.py
```

The service will start on `http://localhost:5000`

For production, use a WSGI server:
```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 ocr_service:app
```

## Usage

### Swift Application

1. Launch the OCR App
2. The Python OCR service must be running on `localhost:5000`
3. **Drag and drop** an image onto the window
4. Or click **Open Image** to select a file
5. Or click **Capture Area** to take a screenshot
6. The recognized text will appear in the text panel
7. Click **Copy Text** to copy to clipboard
8. View history in the right panel
9. Click **Export** to save history as TXT

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/ocr` | POST | Recognize text from image |
| `/history` | GET | Get recognition history |
| `/history/<id>` | DELETE | Delete a history record |
| `/export` | GET | Export history to TXT |
| `/health` | GET | Health check |

### OCR Request Format

```json
{
    "image_path": "/path/to/image.png",
    "base64": "iVBORw0KGgoAAAANSUhEUg...",
    "threshold": 128,
    "kernel_size": 3
}
```

Either `image_path` or `base64` must be provided.

### OCR Response Format

```json
{
    "success": true,
    "text": "Recognized text content",
    "confidence": 85.5,
    "record_id": 123
}
```

## Configuration

### C++ Library Parameters

- `threshold`: Binarization threshold (0-255), default: 128
- `kernel_size`: Denoising kernel size (odd number), default: 3

### Python Service

- Port: 5000 (configurable via `PORT` environment variable)
- Database: SQLite (`ocr_history.db`)
- Image processor: Uses C++ library if available, falls back to OpenCV

## Troubleshooting

### Common Issues

1. **Tesseract not found**
   - Ensure Tesseract is installed and in PATH
   - On macOS: `brew install tesseract tesseract-lang`
   - Verify: `tesseract --version`

2. **C++ library not loading**
   - Check if the library is in `python/lib/`
   - On Windows, ensure Visual C++ Redistributable is installed

3. **Swift app cannot connect to Python service**
   - Ensure Python service is running on port 5000
   - Check firewall settings
   - Test with: `curl http://localhost:5000/health`

4. **OCR accuracy is low**
   - Use higher resolution images
   - Ensure text is clear and well-lit
   - Try adjusting threshold and kernel_size parameters

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Swift AppKit UI                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Drag/Drop   │  │   Screen     │  │    History       │  │
│  │  Image View  │  │   Capture    │  │    Table         │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
│                            │                                │
│                            ▼                                │
│                    ┌──────────────┐                         │
│                    │  OCRService  │                         │
│                    └──────────────┘                         │
└────────────────────────────┬───────────────────────────────┘
                             │ HTTP POST /ocr
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Python Flask Service                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   REST API   │  │   OCR Core   │  │   SQLite DB      │  │
│  │  (Flask)     │  │ (Tesseract) │  │  (History)       │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
│         │                  │                                │
│         │                  ▼                                │
│         │         ┌──────────────────┐                      │
│         │         │ Image Preprocess │                      │
│         │         │  (C++ Library)   │                      │
│         │         └──────────────────┘                      │
└─────────┴───────────────────────────────────────────────────┘
```

## License

This project is provided as-is for educational and personal use.
