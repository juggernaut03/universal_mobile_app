# Flutter App Cloning Automation Script

This script automates the process of cloning a Flutter app and changing its identity, including package names, app names, Firebase configurations, and keystore setup. **Now with interactive mode!**

## Features

- ✅ **Interactive Mode** - User-friendly prompts for all configurations
- ✅ Clone Flutter project with all files (excluding .git, build, .dart_tool)
- ✅ Update app name in pubspec.yaml
- ✅ Change Android package name and app label
- ✅ Update iOS bundle identifier and display name
- ✅ Copy Firebase configuration files (Android & iOS)
- ✅ Setup keystore configuration for Android signing
- ✅ Clean and initialize the new project
- ✅ Generate detailed summary report
- ✅ Colored output with progress indicators
- ✅ Comprehensive error handling and validation

## Usage

### Interactive Mode (Recommended)
```bash
./clone_app.sh
```

The script will prompt you for:
- Source app directory name
- New app name
- Package name
- Firebase configuration (optional)
- Keystore configuration (optional)

### Non-Interactive Mode
```bash
./clone_app.sh --source patelmart --new-name idlibykilo --package com.idlibykilo.app
```

### With Firebase Configuration
```bash
./clone_app.sh --source patelmart --new-name idlibykilo --package com.idlibykilo.app --firebase-config ./idlibykilo
```

### With Keystore Configuration
```bash
./clone_app.sh --source patelmart --new-name idlibykilo --package com.idlibykilo.app \
  --firebase-config ./idlibykilo \
  --keystore ./idlibykilo/idlibykilo.jks \
  --keystore-password idlibykilo \
  --keystore-alias idlibykilo
```

### Show Help
```bash
./clone_app.sh --help
```

## Interactive Mode Experience

When you run `./clone_app.sh` without arguments, you'll see:

```
=== Flutter App Cloning Tool ===

[PROMPT] Enter the source Flutter app directory name (default: patelmart): 
[PROMPT] Enter the new app name (default: mynewapp): 
[PROMPT] Enter the new package name (e.g., com.example.app) (default: com.mynewapp.app): 
[PROMPT] Do you want to configure Firebase (push notifications, analytics)? (Y/n): 
[PROMPT] Enter the path to Firebase config directory (default: ./firebase_config): 
[PROMPT] Do you want to configure Android keystore for app signing? (Y/n): 
[PROMPT] Enter the path to keystore file (default: ./firebase_config/keystore.jks): 
[PROMPT] Enter keystore password (default: password): 
[PROMPT] Enter keystore alias (default: key0): 

=== Configuration Summary ===
Source app: patelmart
New app name: idlibykilo
Package name: com.idlibykilo.app
Firebase config: ./idlibykilo
Keystore: ./idlibykilo/idlibykilo.jks
Keystore alias: idlibykilo

[PROMPT] Proceed with cloning? (Y/n): 
```

## Arguments

- `--source <name>` - Source Flutter app directory name
- `--new-name <name>` - New app name
- `--package <name>` - New package name (e.g., com.example.newapp)
- `--firebase-config <path>` - Path to directory containing Firebase config files
- `--keystore <path>` - Path to keystore file
- `--keystore-password <pwd>` - Keystore password
- `--keystore-alias <alias>` - Keystore alias
- `--non-interactive` - Run in non-interactive mode (requires all args)
- `--help` - Show help message

## Firebase Configuration Directory Structure

The Firebase config directory should contain:
```
firebase_config_dir/
├── google-services.json          # Android Firebase config
├── GoogleService-Info.plist      # iOS/macOS Firebase config
└── [keystore_file].jks          # Keystore file (optional)
```

## What the Script Does

### 1. Project Cloning
- Creates a new directory with the specified name
- Copies all project files using rsync
- Excludes .git, build, and .dart_tool directories

### 2. Configuration Updates
- **pubspec.yaml**: Updates app name and description
- **Android**: Updates namespace, applicationId, package name, and app label
- **iOS**: Updates bundle identifier and display name

### 3. Firebase Configuration
- Copies google-services.json to android/app/
- Copies GoogleService-Info.plist to ios/Runner/ and macos/Runner/

### 4. Keystore Setup
- Copies keystore file to project root
- Creates android/key.properties with keystore configuration

### 5. Project Initialization
- Runs `flutter clean`
- Runs `flutter pub get`

### 6. Summary Report
- Creates CLONE_SUMMARY.md with detailed information about changes

## Example Interactive Session

```
=== Flutter App Cloning Tool ===

[PROMPT] Enter the source Flutter app directory name (default: patelmart): 
[PROMPT] Enter the new app name (default: mynewapp): idlibykilo
[PROMPT] Enter the new package name (e.g., com.example.app) (default: com.idlibykilo.app): 
[PROMPT] Do you want to configure Firebase (push notifications, analytics)? (Y/n): 
[PROMPT] Enter the path to Firebase config directory (default: ./firebase_config): ./idlibykilo
[PROMPT] Do you want to configure Android keystore for app signing? (Y/n): 
[PROMPT] Enter the path to keystore file (default: ./idlibykilo/keystore.jks): ./idlibykilo/idlibykilo.jks
[PROMPT] Enter keystore password (default: password): idlibykilo
[PROMPT] Enter keystore alias (default: key0): idlibykilo

=== Configuration Summary ===
Source app: patelmart
New app name: idlibykilo
Package name: com.idlibykilo.app
Firebase config: ./idlibykilo
Keystore: ./idlibykilo/idlibykilo.jks
Keystore alias: idlibykilo

[PROMPT] Proceed with cloning? (Y/n): 

[INFO] Starting Flutter app cloning process...
[INFO] Cloning project from patelmart to idlibykilo...
[SUCCESS] Project cloned successfully
[INFO] Updating pubspec.yaml...
[SUCCESS] pubspec.yaml updated
[INFO] Updating Android configuration...
[SUCCESS] Android configuration updated
[INFO] Updating iOS configuration...
[SUCCESS] iOS configuration updated
[INFO] Copying Firebase configuration files...
[SUCCESS] Copied google-services.json
[SUCCESS] Copied GoogleService-Info.plist
[SUCCESS] Firebase configuration files copied
[INFO] Setting up keystore configuration...
[SUCCESS] Keystore configuration setup complete
[INFO] Initializing the new project...
[INFO] Cleaning project...
[INFO] Getting dependencies...
[SUCCESS] Project initialization complete
[INFO] Creating summary report...
[SUCCESS] Summary report created: idlibykilo/CLONE_SUMMARY.md
[SUCCESS] App cloning completed successfully!
[INFO] New app is ready at: idlibykilo
[INFO] Check CLONE_SUMMARY.md for details

=== Next Steps ===
1. cd idlibykilo
2. flutter run
3. Update app icons and branding
4. Test on both Android and iOS
```

## Error Handling

The script includes comprehensive error handling:
- Validates all required arguments
- Checks if source directory exists
- Ensures target directory doesn't exist
- Validates package name format
- Handles missing Firebase config files gracefully
- Provides clear error messages with colored output
- Confirms user intent before proceeding

## Prerequisites

- Bash shell (macOS/Linux)
- Flutter SDK installed
- rsync command available
- sed command available

## Files Modified

- `pubspec.yaml`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `ios/Runner.xcodeproj/project.pbxproj`

## Files Added (if specified)

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `android/key.properties`
- `[keystore_file].jks`

## Next Steps After Cloning

1. **Update App Icons**: Replace app icons in assets/images/
2. **Modify Branding**: Update colors, logos, and branding elements
3. **Update API Endpoints**: Change hardcoded URLs and API endpoints
4. **Test the App**: Run on both Android and iOS devices
5. **Update Documentation**: Modify README and other documentation files
6. **Configure CI/CD**: Update build configurations if needed

## Troubleshooting

### Common Issues

1. **Permission Denied**: Make sure the script is executable
   ```bash
   chmod +x clone_app.sh
   ```

2. **Flutter Not Found**: Ensure Flutter SDK is in PATH
   ```bash
   flutter doctor
   ```

3. **Package Name Format**: Use valid package name format
   ```bash
   # Valid: com.example.app
   # Invalid: com.example-app
   ```

4. **Firebase Config Missing**: Check if Firebase config files exist in specified directory

5. **Interactive Mode Issues**: If prompts don't work, try running in non-interactive mode

### Debug Mode

To see more detailed output, you can modify the script to add `set -x` at the beginning for debug mode.

## Contributing

Feel free to extend this script with additional features:
- Support for more platforms (web, desktop)
- Additional configuration file updates
- Custom asset copying
- Git repository initialization
- CI/CD configuration updates
- More interactive prompts for advanced configurations 