#!/bin/bash

# Flutter App Cloning and Renaming Script
# This script automates the process of cloning a Flutter app and changing its identity

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

print_prompt() {
    echo -e "${CYAN}[PROMPT]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --source <name>           - Source Flutter app directory name"
    echo "  --new-name <name>         - New app name"
    echo "  --package <name>          - New package name (e.g., com.example.newapp)"
    echo "  --firebase-config <path>  - Path to directory containing Firebase config files"
    echo "  --keystore <path>         - Path to keystore file"
    echo "  --keystore-password <pwd> - Keystore password"
    echo "  --keystore-alias <alias>  - Keystore alias"
    echo "  --non-interactive         - Run in non-interactive mode (requires all args)"
    echo "  --help                    - Show this help message"
    echo ""
    echo "Interactive Mode (default):"
    echo "  $0"
    echo ""
    echo "Non-interactive Mode:"
    echo "  $0 --source patelmart --new-name idlibykilo --package com.idlibykilo.app"
    echo ""
    echo "Firebase config directory should contain:"
    echo "  - google-services.json (for Android)"
    echo "  - GoogleService-Info.plist (for iOS/macOS)"
    echo "  - [keystore_file].jks (keystore file)"
}

# Function to get user input with default value
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        print_prompt "$prompt (default: $default): "
    else
        print_prompt "$prompt: "
    fi
    
    read -r user_input
    
    # If user just pressed Enter, use default value
    if [ -z "$user_input" ] && [ -n "$default" ]; then
        user_input="$default"
    fi
    
    eval "$var_name=\"$user_input\""
}

# Function to get yes/no input
get_yes_no() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    while true; do
        if [ "$default" = "y" ]; then
            print_prompt "$prompt (Y/n): "
        else
            print_prompt "$prompt (y/N): "
        fi
        
        read -r user_input
        
        # If user just pressed Enter, use default value
        if [ -z "$user_input" ]; then
            user_input="$default"
        fi
        
        case $user_input in
            [Yy]* ) eval "$var_name=\"y\""; break;;
            [Nn]* ) eval "$var_name=\"n\""; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Function to validate arguments
validate_args() {
    # Check for help flag first
    for arg in "$@"; do
        if [ "$arg" = "--help" ]; then
            show_usage
            exit 0
        fi
    done
    
    # Check if non-interactive mode is requested
    NON_INTERACTIVE=false
    for arg in "$@"; do
        if [ "$arg" = "--non-interactive" ]; then
            NON_INTERACTIVE=true
            break
        fi
    done
    
    if [ "$NON_INTERACTIVE" = true ]; then
        # Parse command line arguments for non-interactive mode
        while [[ $# -gt 0 ]]; do
            case $1 in
                --source)
                    SOURCE_APP_NAME="$2"
                    shift 2
                    ;;
                --new-name)
                    NEW_APP_NAME="$2"
                    shift 2
                    ;;
                --package)
                    NEW_PACKAGE_NAME="$2"
                    shift 2
                    ;;
                --firebase-config)
                    FIREBASE_CONFIG_DIR="$2"
                    shift 2
                    ;;
                --keystore)
                    KEYSTORE_PATH="$2"
                    shift 2
                    ;;
                --keystore-password)
                    KEYSTORE_PASSWORD="$2"
                    shift 2
                    ;;
                --keystore-alias)
                    KEYSTORE_ALIAS="$2"
                    shift 2
                    ;;
                --non-interactive)
                    shift
                    ;;
                *)
                    print_error "Unknown option: $1"
                    show_usage
                    exit 1
                    ;;
            esac
        done
        
        # Validate required arguments for non-interactive mode
        if [ -z "$SOURCE_APP_NAME" ] || [ -z "$NEW_APP_NAME" ] || [ -z "$NEW_PACKAGE_NAME" ]; then
            print_error "Non-interactive mode requires --source, --new-name, and --package arguments"
            show_usage
            exit 1
        fi
    else
        # Interactive mode - get inputs from user
        echo -e "${CYAN}=== Flutter App Cloning Tool ===${NC}"
        echo ""
        
        # Get source app name - use current directory name as default
        current_dir_name=$(basename "$PWD")
        get_input "Enter the source Flutter app directory name" "$current_dir_name" "SOURCE_APP_NAME"
        
        # Get new app name
        get_input "Enter the new app name" "mynewapp" "NEW_APP_NAME"
        
        # Get package name
        get_input "Enter the new package name (e.g., com.example.app)" "com.$NEW_APP_NAME.app" "NEW_PACKAGE_NAME"
        
        # Ask about Firebase configuration
        get_yes_no "Do you want to configure Firebase (push notifications, analytics)?" "y" "USE_FIREBASE"
        
        if [ "$USE_FIREBASE" = "y" ]; then
            get_input "Enter the path to Firebase config directory" "./firebase_config" "FIREBASE_CONFIG_DIR"
            
            # Ask about keystore
            get_yes_no "Do you want to configure Android keystore for app signing?" "y" "USE_KEYSTORE"
            
            if [ "$USE_KEYSTORE" = "y" ]; then
                # Use a more sensible default for keystore path
                keystore_default="$FIREBASE_CONFIG_DIR/keystore.jks"
                get_input "Enter the path to keystore file" "$keystore_default" "KEYSTORE_PATH"
                get_input "Enter keystore password" "password" "KEYSTORE_PASSWORD"
                get_input "Enter keystore alias" "key0" "KEYSTORE_ALIAS"
            fi
        fi
        
        # Show summary and confirm
        echo ""
        echo -e "${CYAN}=== Configuration Summary ===${NC}"
        echo "Source app: $SOURCE_APP_NAME"
        echo "New app name: $NEW_APP_NAME"
        echo "Package name: $NEW_PACKAGE_NAME"
        if [ "$USE_FIREBASE" = "y" ]; then
            echo "Firebase config: $FIREBASE_CONFIG_DIR"
            if [ "$USE_KEYSTORE" = "y" ]; then
                echo "Keystore: $KEYSTORE_PATH"
                echo "Keystore alias: $KEYSTORE_ALIAS"
            fi
        fi
        echo ""
        
        get_yes_no "Proceed with cloning?" "y" "CONFIRM"
        
        if [ "$CONFIRM" != "y" ]; then
            print_status "Operation cancelled by user"
            exit 0
        fi
    fi
    
    # Validate source app exists
    if [ ! -d "$SOURCE_APP_NAME" ]; then
        print_error "Source app directory '$SOURCE_APP_NAME' does not exist"
        exit 1
    fi
    
    # Validate new app name doesn't exist
    if [ -d "$NEW_APP_NAME" ]; then
        print_error "Target directory '$NEW_APP_NAME' already exists"
        exit 1
    fi
    
    # Validate package name format
    if [[ ! "$NEW_PACKAGE_NAME" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$ ]]; then
        print_error "Invalid package name format: $NEW_PACKAGE_NAME"
        exit 1
    fi
}

# Function to clone the project
clone_project() {
    print_status "Cloning project from $SOURCE_APP_NAME to $NEW_APP_NAME..."
    
    # Create new directory and copy files
    rsync -av --exclude='.git/' --exclude='build/' --exclude='.dart_tool/' --exclude="$NEW_APP_NAME/" "$SOURCE_APP_NAME/" "$NEW_APP_NAME/"
    
    print_success "Project cloned successfully"
}

# Function to update pubspec.yaml
update_pubspec() {
    print_status "Updating pubspec.yaml..."
    
    local pubspec_file="$NEW_APP_NAME/pubspec.yaml"
    
    # Update app name and description
    sed -i.bak "s/^name: .*/name: $NEW_APP_NAME/" "$pubspec_file"
    sed -i.bak "s/^description: .*/description: \"$NEW_APP_NAME - Flutter App\"/" "$pubspec_file"
    
    # Remove backup file
    rm -f "${pubspec_file}.bak"
    
    print_success "pubspec.yaml updated"
}

# Function to update Android configuration
update_android_config() {
    print_status "Updating Android configuration..."
    
    local build_gradle="$NEW_APP_NAME/android/app/build.gradle.kts"
    local manifest="$NEW_APP_NAME/android/app/src/main/AndroidManifest.xml"
    
    # Update namespace and applicationId in build.gradle.kts
    sed -i.bak "s/namespace = \"com\.[a-zA-Z0-9_]*\.app\"/namespace = \"$NEW_PACKAGE_NAME\"/" "$build_gradle"
    sed -i.bak "s/applicationId = \"com\.[a-zA-Z0-9_]*\.app\"/applicationId = \"$NEW_PACKAGE_NAME\"/" "$build_gradle"
    
    # Update package in AndroidManifest.xml
    sed -i.bak "s/package=\"com\.[a-zA-Z0-9_]*\.app\"/package=\"$NEW_PACKAGE_NAME\"/" "$manifest"
    
    # Update app label in AndroidManifest.xml
    sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"$NEW_APP_NAME\"/" "$manifest"
    
    # Remove backup files
    rm -f "${build_gradle}.bak" "${manifest}.bak"
    
    print_success "Android configuration updated"
}

# Function to update iOS configuration
update_ios_config() {
    print_status "Updating iOS configuration..."
    
    local info_plist="$NEW_APP_NAME/ios/Runner/Info.plist"
    local project_pbxproj="$NEW_APP_NAME/ios/Runner.xcodeproj/project.pbxproj"
    
    # Update CFBundleDisplayName and CFBundleName in Info.plist
    sed -i.bak "s/<string>.*<\/string>/<string>$NEW_APP_NAME<\/string>/" "$info_plist"
    sed -i.bak "/CFBundleName/,/<string>/s/<string>.*<\/string>/<string>$NEW_APP_NAME<\/string>/" "$info_plist"
    
    # Update PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj
    sed -i.bak "s/PRODUCT_BUNDLE_IDENTIFIER = com\.[a-zA-Z0-9_]*\.iosapp;/PRODUCT_BUNDLE_IDENTIFIER = $NEW_PACKAGE_NAME;/g" "$project_pbxproj"
    sed -i.bak "s/PRODUCT_BUNDLE_IDENTIFIER = com\.[a-zA-Z0-9_]*\.RunnerTests;/PRODUCT_BUNDLE_IDENTIFIER = $NEW_PACKAGE_NAME.RunnerTests;/g" "$project_pbxproj"
    
    # Remove backup files
    rm -f "${info_plist}.bak" "${project_pbxproj}.bak"
    
    print_success "iOS configuration updated"
}

# Function to copy Firebase configuration files
copy_firebase_config() {
    if [ -z "$FIREBASE_CONFIG_DIR" ]; then
        print_warning "No Firebase config directory specified, skipping Firebase config copy"
        return
    fi
    
    if [ ! -d "$FIREBASE_CONFIG_DIR" ]; then
        print_error "Firebase config directory '$FIREBASE_CONFIG_DIR' does not exist"
        return
    fi
    
    print_status "Copying Firebase configuration files..."
    
    # Copy Android Firebase config
    if [ -f "$FIREBASE_CONFIG_DIR/google-services.json" ]; then
        cp "$FIREBASE_CONFIG_DIR/google-services.json" "$NEW_APP_NAME/android/app/"
        print_success "Copied google-services.json"
    else
        print_warning "google-services.json not found in $FIREBASE_CONFIG_DIR"
    fi
    
    # Copy iOS Firebase config
    if [ -f "$FIREBASE_CONFIG_DIR/GoogleService-Info.plist" ]; then
        cp "$FIREBASE_CONFIG_DIR/GoogleService-Info.plist" "$NEW_APP_NAME/ios/Runner/"
        cp "$FIREBASE_CONFIG_DIR/GoogleService-Info.plist" "$NEW_APP_NAME/macos/Runner/"
        print_success "Copied GoogleService-Info.plist"
    else
        print_warning "GoogleService-Info.plist not found in $FIREBASE_CONFIG_DIR"
    fi
    
    print_success "Firebase configuration files copied"
}

# Function to setup keystore configuration
setup_keystore() {
    if [ -z "$KEYSTORE_PATH" ] || [ -z "$KEYSTORE_PASSWORD" ] || [ -z "$KEYSTORE_ALIAS" ]; then
        print_warning "Keystore configuration incomplete, skipping keystore setup"
        return
    fi
    
    if [ ! -f "$KEYSTORE_PATH" ]; then
        print_error "Keystore file '$KEYSTORE_PATH' does not exist"
        return
    fi
    
    print_status "Setting up keystore configuration..."
    
    # Copy keystore file
    cp "$KEYSTORE_PATH" "$NEW_APP_NAME/"
    
    # Create key.properties file
    cat > "$NEW_APP_NAME/android/key.properties" << EOF
storeFile=../$(basename "$KEYSTORE_PATH")
storePassword=$KEYSTORE_PASSWORD
keyAlias=$KEYSTORE_ALIAS
keyPassword=$KEYSTORE_PASSWORD
EOF
    
    print_success "Keystore configuration setup complete"
}

# Function to clean and initialize the project
initialize_project() {
    print_status "Initializing the new project..."
    
    cd "$NEW_APP_NAME"
    
    # Clean the project
    print_status "Cleaning project..."
    flutter clean
    
    # Get dependencies
    print_status "Getting dependencies..."
    flutter pub get
    
    print_success "Project initialization complete"
}

# Function to create a summary report
create_summary() {
    print_status "Creating summary report..."
    
    cat > "$NEW_APP_NAME/CLONE_SUMMARY.md" << EOF
# App Cloning Summary

## Original App
- Name: $SOURCE_APP_NAME
- Package: com.patelrmart.app

## New App
- Name: $NEW_APP_NAME
- Package: $NEW_PACKAGE_NAME

## Changes Made

### 1. Project Structure
- Cloned from $SOURCE_APP_NAME to $NEW_APP_NAME
- Excluded .git, build, and .dart_tool directories

### 2. Configuration Updates
- Updated pubspec.yaml with new app name
- Updated Android package name and app label
- Updated iOS bundle identifier and display name

### 3. Firebase Configuration
$(if [ -n "$FIREBASE_CONFIG_DIR" ]; then
    echo "- Copied Firebase configuration files from $FIREBASE_CONFIG_DIR"
else
    echo "- No Firebase configuration copied (not specified)"
fi)

### 4. Keystore Configuration
$(if [ -n "$KEYSTORE_PATH" ]; then
    echo "- Keystore file: $(basename "$KEYSTORE_PATH")"
    echo "- Keystore alias: $KEYSTORE_ALIAS"
else
    echo "- No keystore configuration (not specified)"
fi)

## Next Steps
1. Update app icons and assets
2. Modify color schemes and branding
3. Update API endpoints and URLs
4. Test the app on both Android and iOS
5. Update any hardcoded references to the old app name

## Files Modified
- pubspec.yaml
- android/app/build.gradle.kts
- android/app/src/main/AndroidManifest.xml
- ios/Runner/Info.plist
- ios/Runner.xcodeproj/project.pbxproj

## Files Added
$(if [ -n "$FIREBASE_CONFIG_DIR" ]; then
    echo "- android/app/google-services.json"
    echo "- ios/Runner/GoogleService-Info.plist"
    echo "- macos/Runner/GoogleService-Info.plist"
fi)
$(if [ -n "$KEYSTORE_PATH" ]; then
    echo "- $(basename "$KEYSTORE_PATH")"
    echo "- android/key.properties"
fi)

Generated on: $(date)
EOF
    
    print_success "Summary report created: $NEW_APP_NAME/CLONE_SUMMARY.md"
}

# Main execution
main() {
    print_status "Starting Flutter app cloning process..."
    
    # Validate arguments
    validate_args "$@"
    
    # Execute steps
    clone_project
    update_pubspec
    update_android_config
    update_ios_config
    copy_firebase_config
    setup_keystore
    initialize_project
    create_summary
    
    print_success "App cloning completed successfully!"
    print_status "New app is ready at: $NEW_APP_NAME"
    print_status "Check CLONE_SUMMARY.md for details"
    
    echo ""
    echo -e "${GREEN}=== Next Steps ===${NC}"
    echo "1. cd $NEW_APP_NAME"
    echo "2. flutter run"
    echo "3. Update app icons and branding"
    echo "4. Test on both Android and iOS"
}

# Run main function with all arguments
main "$@" 