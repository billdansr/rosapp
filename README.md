# RosApp

[![Build Status](https://img.shields.io/github/actions/workflow/status/your-username/rosapp/build.yml?branch=main)](https://github.com/your-username/rosapp/actions)
[![License](https://img.shields.io/github/license/your-username/rosapp)](LICENSE)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/platform-Windows-blue)](https://flutter.dev/desktop)

A Windows desktop point of sale and inventory management system built with Flutter.

<!-- Optional: Add a screenshot or GIF of the application -->
<!-- ![RosApp Screenshot](path/to/screenshot.png) -->

## What's New in v1.1.0
- Sound feedback for an improved user experience.
- Various bug fixes and stability improvements.

## Features

- **Inventory Management**
  - Product catalog with SKU/barcode support
  - Category management
  - Purchase order tracking

- **Point of Sale**
  - Barcode scanning
  - Quick product search
  - Cart management
  - Receipt printing
  - Cash transaction handling

- **Reporting**
  - Daily sales reports
  - Inventory status
  - Product performance
  - Purchase history

## System Requirements

- Windows 10/11
- 4GB RAM minimum
- 500MB free disk space
- 1280x720 minimum screen resolution
- Camera (optional, for barcode scanning)
- Printer (optional, for receipts)

## Development Setup

1. Install Flutter SDK
```bash
flutter doctor
```

2. Enable Windows Desktop Support
```bash
flutter config --enable-windows-desktop
```

3. Install Dependencies
```bash
flutter pub get
```

4. Run the Application
```bash
flutter run -d windows
```

## Build

To create a release build:
```bash
flutter build windows
```

This will generate an MSIX installer at `build/windows/runner/Release/`.

## Project Structure

```
lib/
├── models/      # Data models
├── screens/     # UI screens
├── services/    # Business logic
├── widgets/     # Reusable components
└── main.dart    # Entry point
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

Copyright (c) 2024. All rights reserved.

## Support

For technical support or bug reports, please open an issue on our GitHub repository.
