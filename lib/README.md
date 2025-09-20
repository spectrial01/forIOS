# Project Nexus - Mobile Tracking Device App

## Project Structure

This Flutter app is organized with a clean architecture following the user's folder structure requirements:

```
lib/
├── main.dart                 # App entry point with routing
├── models/                   # Data models
│   └── user_model.dart      # User data model
├── providers/               # State management
│   └── auth_provider.dart   # Authentication state provider
├── services/                # Business logic services
│   └── auth_service.dart    # Authentication API service
├── screens/                 # UI screens
│   ├── login_screen.dart    # Login page
│   ├── register_screen.dart # Registration page
│   └── home_screen.dart     # Main dashboard
└── widgets/                 # Reusable UI components
    ├── custom_text_field.dart # Custom text input widget
    └── custom_button.dart     # Custom button widget
```

## Features

- **Modern Login UI**: Beautiful gradient design with form validation
- **User Registration**: Complete signup flow with password confirmation
- **State Management**: Provider pattern for clean state handling
- **Local Storage**: Persistent login using SharedPreferences
- **Responsive Design**: Optimized for Android mobile devices
- **Form Validation**: Email and password validation
- **Error Handling**: User-friendly error messages
- **Loading States**: Visual feedback during API calls

## Dependencies

- `provider`: State management
- `http`: API communication
- `shared_preferences`: Local data storage
- `form_field_validator`: Form validation

## Getting Started

1. Run `flutter pub get` to install dependencies
2. Update the API endpoints in `auth_service.dart`
3. Run `flutter run` to start the app

## API Integration

The app is ready for backend integration. Update the following in `lib/services/auth_service.dart`:
- `baseUrl`: Your API base URL
- `loginEndpoint`: Login API endpoint
- `registerEndpoint`: Registration API endpoint

## Customization

- Colors: Update the color scheme in `main.dart` and individual screens
- Branding: Replace the app icon and title
- API: Modify the service layer for your backend requirements
