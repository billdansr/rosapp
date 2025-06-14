# RosApp

A Windows desktop point of sale and inventory management system built with Flutter.

## Features

- **Inventory Management**
  - Product catalog with SKU/barcode support
  - Stock level tracking  # RosApp v1.1.0.1
  ---
  A Windows desktop point of sale and inventory management system built with Flutter.
  
  ## What's New in 1.1.0
  - Sound feedback for better user experience
  - Various bug fixes and stability improvements
  
  [Previous version details and rest of README remain the same...]
  - Category management
  - Low stock alerts
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

Copyright © 2025. All rights reserved.

## Support

For technical support or bug reports, please open an issue on our GitHub repository.
