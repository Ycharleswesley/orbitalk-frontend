# UTELO Flutter App

A Flutter-based real-time voice translation mobile application with chat, calling, and translation features.

## Features

- **Real-time Voice Translation**: Speak and hear translations during calls
- **Text-to-Text Translation**: Translate chat messages using Azure Translator API
- **Voice Calling**: VoIP calls using Zego Cloud SDK
- **Chat Messaging**: Real-time text messaging with Firebase
- **Multi-language Support**: 11 Indian languages
- **User Authentication**: Phone number OTP via Firebase Auth
- **Profile Management**: Avatars, display names, status
- **Push Notifications**: Call and message notifications

## Text Translation

The app translates text messages via the Backend, which uses Google Cloud Translation API.

### How It Works

1. **TranslationService** (`lib/services/translation_service.dart`) sends text to Backend API (`/translate`)
2. Backend forwards request to Google Cloud Translate
3. Backend returns translated text to Frontend
4. Supports auto-detection of source language

### API Configuration

The translation service requires no local keys. It communicates directly with your deployed Backend.

### Usage Example

```dart
final translationService = TranslationService();
final translatedText = await translationService.translateText(
  'Hello, how are you?',
  toLang: 'hi',  // Target language (Hindi)
  fromLang: 'en', // Source language (optional, can auto-detect)
);
// Result: "नमस्ते, आप कैसे हैं?"
```

### Supported Languages

| Code | Language |
|------|----------|
| `en` | English |
| `hi` | Hindi |
| `te` | Telugu |
| `ta` | Tamil |
| `kn` | Kannada |
| `ml` | Malayalam |
| `mr` | Marathi |
| `bn` | Bengali |
| `gu` | Gujarati |
| `pa` | Punjabi |
| `ur` | Urdu |

## Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart SDK ^3.8.1
- Android Studio / VS Code with Flutter extensions
- Firebase project with configured apps
- Zego Cloud account for calling features

## Installation

### 1. Clone and Install Dependencies

```bash
cd "orbitalk backup/orbitalk backup"
flutter pub get
```

### 2. Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Add Android app with package name from `android/app/build.gradle`
3. Download `google-services.json` and place in `android/app/`
4. Enable Authentication (Phone provider)
5. Set up Cloud Firestore
6. Set up Firebase Storage
7. Enable Firebase Cloud Messaging

### 3. Zego Cloud Setup

1. Create account at [Zego Cloud Console](https://console.zegocloud.com)
2. Create a project and get App ID and App Sign
3. Update credentials in the app configuration

### 4. Backend Configuration

Update the WebSocket URL in `lib/config/translation_config.dart`:

```dart
class TranslationConfig {
  static const String websocketUrl = 'wss://your-backend-domain.com';
  // ...
}
```

## Running the App

### Debug Mode
```bash
flutter run
```

### Release Build (Android)
```bash
flutter build apk --release
```

### Release Build (iOS)
```bash
flutter build ios --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── config/
│   └── translation_config.dart
├── models/
│   ├── chat_model.dart
│   ├── message_model.dart
│   ├── call_model.dart
│   └── user_model.dart
├── screens/
│   ├── splash_screen.dart
│   ├── welcome_screen.dart
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── otp_screen.dart
│   ├── main_screen.dart
│   ├── chats_screen.dart
│   ├── chat_detail_screen.dart
│   ├── calls_screen.dart
│   ├── active_call_screen.dart
│   ├── incoming_call_screen.dart
│   ├── outgoing_call_screen.dart
│   ├── settings_screen.dart
│   ├── profile_view_screen.dart
│   ├── edit_profile_screen.dart
│   └── ...
├── services/
│   ├── auth_service.dart
│   ├── call_service.dart
│   ├── chat_service.dart
│   ├── websocket_service.dart
│   ├── translation_service.dart
│   ├── zego_translation_service.dart
│   ├── audio_processor_service.dart
│   ├── notification_service.dart
│   ├── storage_service.dart
│   ├── settings_service.dart
│   └── ...
├── widgets/
│   └── (reusable UI components)
└── utils/
    └── app_colors.dart
```

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Phone authentication |
| `cloud_firestore` | Real-time database |
| `firebase_storage` | File/image storage |
| `firebase_messaging` | Push notifications |
| `zego_express_engine` | Voice/video calling |
| `zego_uikit_prebuilt_call` | Call UI components |
| `web_socket_channel` | WebSocket for translation |
| `sound_stream` | Audio streaming |
| `provider` | State management |
| `image_picker` | Photo selection |
| `cached_network_image` | Image caching |

## Firestore Data Structure

### Users Collection
```
users/{userId}
├── displayName: string
├── phoneNumber: string
├── avatar: string (URL)
├── language: string
├── isOnline: boolean
├── lastSeen: timestamp
└── createdAt: timestamp
```

### Chats Collection
```
chats/{chatId}
├── participants: array
├── lastMessage: string
├── lastMessageTime: timestamp
└── messages/{messageId}
    ├── senderId: string
    ├── text: string
    ├── timestamp: timestamp
    └── type: string
```

### Calls Collection
```
calls/{callId}
├── callerId: string
├── callerName: string
├── receiverId: string
├── status: string
├── startTime: timestamp
└── endTime: timestamp
```

## Troubleshooting

### Build Errors
```bash
flutter clean
flutter pub get
```

### Firebase Issues
- Verify `google-services.json` is in correct location
- Check Firebase console for correct package name
- Ensure SHA-1/SHA-256 fingerprints are added

### Call Not Connecting
- Verify Zego Cloud credentials
- Check backend WebSocket is running
- Ensure both users have internet connectivity

### Translation Not Working
- Verify backend is deployed and accessible
- Check WebSocket URL in `translation_config.dart`
- Review backend logs for Azure API errors

## Building for Production

### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
# Then archive in Xcode
```

## Permissions Required

- **Camera**: Video calls
- **Microphone**: Voice calls and translation
- **Notifications**: Call and message alerts
- **Photos/Storage**: Sending images in chat