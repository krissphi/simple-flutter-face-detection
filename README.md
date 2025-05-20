# Flutter Face Detection

A simple Flutter application that uses machine learning to detect faces in real-time using your device's camera.

## Features

- Real-time face detection
- Marks detected faces with bounding boxes

## Requirements

- Flutter SDK 3.0.0 or higher
- Dart 2.17.0 or higher
- Android Studio / VS Code
- A physical device with camera (emulators may not work properly with camera features)

## Installation

1. Clone this repository
   ```bash
   git clone https://github.com/krissphi/simple-flutter-face-detection.git
   ```

2. Navigate to the project directory
   ```bash
   cd simple-flutter-face-detection
   ```

3. Install dependencies
   ```bash
   flutter pub get
   ```

4. Run the app
   ```bash
   flutter run
   ```

## Dependencies

This app uses the following packages:

- `camera: ^0.10.6` - For accessing the device camera
- `permission_handler: ^12.0.0+1` - For handling camera permissions
- `path_provider: ^2.1.1` - For saving face images
- `provider: ^6.1.2` - For state management
- `google_mlkit_face_detection: ^0.13.1` - For face detection capabilities

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  permission_handler: ^12.0.0+1
  path_provider: ^2.1.1
  camera: ^0.10.6
  provider: ^6.1.2
  google_mlkit_face_detection: ^0.13.1

```

## Setup

### Android

1. Add camera permission to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   ```

### iOS

1. Add camera usage description to `ios/Runner/Info.plist`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>This app needs camera access to detect faces</string>
   ```

## Usage

1. Launch the app
2. Grant camera permissions when prompted
3. Point your camera at faces to see detection in action

### Basic Implementation

```dart
// Example code for initializing face detection
final faceDetector = GoogleMlKit.vision.faceDetector(
  FaceDetectorOptions(
    enableClassification: true,
    enableLandmarks: true,
    enableContours: true,
    enableTracking: true,
  ),
);

// Process image and detect faces
Future<List<Face>> processImage(InputImage inputImage) async {
  return await faceDetector.processImage(inputImage);
}
```

## To Do
- [ ] Capture and save image
- [ ] More toggle options (face count, face landmarks, face classification)
- [ ] Improve UI
- [ ] Improve Code

## Troubleshooting

Common issues and solutions:

1. **Camera permission denied**
   - Go to your device settings and enable camera permission for the app

2. **App crashes on startup**
   - Ensure your device meets the minimum requirements
   - Try reinstalling the app

3. **Face detection not working**
   - Ensure good lighting conditions
   - Hold the phone steady
   - Make sure faces are clearly visible

4. **Camera orientation issue**
   - use camera version 0.10.6 (0.11.0 and above has orientation and mirroring issues)

## Acknowledgements

- [Flutter Camera Plugin](https://pub.dev/packages/camera) for the camera implementation
- [Google ML Kit Face Detection](https://pub.dev/packages/google_mlkit_face_detection) for the face detection implementation
