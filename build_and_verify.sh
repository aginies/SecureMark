#!/bin/bash

# Configuration
FLUTTER_PATH="/home/aginies/devel/flutter/bin/flutter"
DART_PATH="/home/aginies/devel/flutter/bin/dart"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
APKSIGNER_PATH="$HOME/Android/Sdk/build-tools/36.1.0/apksigner"
KEYSTORE_PATH="android/upload-keystore.jks"

# OS Detection
IS_MACOS=false
IS_WINDOWS=false
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    IS_WINDOWS=true
fi

function show_help() {
    echo "SecureMark Build & Verify Script"
    echo "Usage: ./build_and_verify.sh [command1] [command2] ..."
    echo ""
    echo "Available commands:"
    echo "  create_keystore   - Generate a new upload-keystore.jks (interactive)"
    echo "  cleanup           - Remove build artifacts (flutter clean)"
    echo "  update_deps       - Update flutter dependencies (pub get)"
    echo "  format_code       - Format all dart files"
    echo "  format_check      - Check if dart files are formatted"
    echo "  quality_checks    - Run format check, analyze and tests"
    echo "  generate_assets   - Regenerate icons, splash screens and localizations"
    echo "  increment_version - Increment build number in pubspec.yaml"
    echo "  build_apk         - Build signed release APK"
    echo "  build_aab         - Build signed release App Bundle"
    echo "  build_ios         - Build release iOS (macOS only)"
    echo "  build_macos       - Build release macOS (macOS only)"
    echo "  build_windows     - Build release Windows (Windows only)"
    echo "  verify_apk        - Verify APK signature with apksigner"
    echo "  verify_aab        - Verify AAB signature with jarsigner"
    echo "  collect_artifacts - Move and rename artifacts to releases/ folder"
    echo "  all               - Run full pipeline in sequence (OS dependent)"
    echo "  help              - Show this help message"
}

function cleanup() {
    echo "[INFO] Cleaning up previous builds..."
    $FLUTTER_PATH clean
}

function update_deps() {
    echo "[INFO] Updating Flutter dependencies..."
    $FLUTTER_PATH pub get
}

function format_code() {
    echo "[INFO] Formatting code..."
    $DART_PATH format .
}

function format_check() {
    echo "[INFO] Checking code formatting..."
    $DART_PATH format --output=none --set-exit-if-changed . || { echo "[ERROR] Code not formatted. Run './build_and_verify.sh format_code'."; exit 1; }
}

function quality_checks() {
    format_check

    echo "[INFO] Running static analysis (lib/ only)..."
    $FLUTTER_PATH analyze lib || { echo "[ERROR] Analysis failed. Fix issues before building."; exit 1; }
    
    echo "[INFO] Running tests..."
    $FLUTTER_PATH test test/ || { echo "[ERROR] Tests failed. Fix issues before building."; exit 1; }
    
    echo "[SUCCESS] Quality checks passed."
}

function generate_assets() {
    echo "[INFO] Regenerating launcher icons..."
    $FLUTTER_PATH pub run flutter_launcher_icons || echo "[WARNING] Icon generation failed, continuing..."
    
    echo "[INFO] Generating localization files..."
    $FLUTTER_PATH gen-l10n || echo "[WARNING] Localization generation failed, continuing..."
}

function increment_version() {
    echo "[INFO] Incrementing build number..."
    VERSION_LINE=$(grep "version: " pubspec.yaml)
    VERSION_NAME=$(echo $VERSION_LINE | cut -d' ' -f2 | cut -d'+' -f1)
    BUILD_NUMBER=$(echo $VERSION_LINE | cut -d'+' -f2)
    NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
    
    NEW_VERSION="version: $VERSION_NAME+$NEW_BUILD_NUMBER"
    sed -i "s/$VERSION_LINE/$NEW_VERSION/g" pubspec.yaml
    
    echo "[SUCCESS] Version updated to $VERSION_NAME+$NEW_BUILD_NUMBER"
}

function build_apk() {
    VERSION_LINE=$(grep "version: " pubspec.yaml)
    VERSION_NAME=$(echo $VERSION_LINE | cut -d' ' -f2 | cut -d'+' -f1)
    BUILD_NUMBER=$(echo $VERSION_LINE | cut -d'+' -f2)
    VERSION_PKG=$(echo $VERSION_NAME | tr '.' '_')
    TARGET_PKG="org.ginies.secure_mark.v$VERSION_PKG"
    echo "[INFO] Building Release APK v$VERSION_NAME+$BUILD_NUMBER (Package: $TARGET_PKG)..."
    $FLUTTER_PATH build apk --release --build-name=$VERSION_NAME --build-number=$BUILD_NUMBER \
        --dart-define=TARGET_PACKAGE=$TARGET_PKG
}

function build_aab() {
    VERSION_LINE=$(grep "version: " pubspec.yaml)
    VERSION_NAME=$(echo $VERSION_LINE | cut -d' ' -f2 | cut -d'+' -f1)
    BUILD_NUMBER=$(echo $VERSION_LINE | cut -d'+' -f2)
    VERSION_PKG=$(echo $VERSION_NAME | tr '.' '_')
    TARGET_PKG="org.ginies.secure_mark.v$VERSION_PKG"
    echo "[INFO] Building Release App Bundle (AAB) v$VERSION_NAME+$BUILD_NUMBER (Package: $TARGET_PKG)..."
    $FLUTTER_PATH build appbundle --release --build-name=$VERSION_NAME --build-number=$BUILD_NUMBER \
        --dart-define=TARGET_PACKAGE=$TARGET_PKG
}

function build_ios() {
    if [ "$IS_MACOS" = false ]; then
        echo "[SKIP] iOS build requires macOS."
        return
    fi
    VERSION_LINE=$(grep "version: " pubspec.yaml)
    VERSION_NAME=$(echo $VERSION_LINE | cut -d' ' -f2 | cut -d'+' -f1)
    BUILD_NUMBER=$(echo $VERSION_LINE | cut -d'+' -f2)
    echo "[INFO] Building Release iOS (No Codesign) v$VERSION_NAME+$BUILD_NUMBER..."
    $FLUTTER_PATH build ios --release --no-codesign --build-name=$VERSION_NAME --build-number=$BUILD_NUMBER
    
    if [ -d "build/ios/iphoneos/Runner.app" ]; then
        echo "[INFO] Packaging iOS Runner.app into ZIP..."
        cd build/ios/iphoneos
        zip -r ../../../secure-mark-ios.zip Runner.app > /dev/null
        cd ../../..
        echo "[SUCCESS] iOS build packaged at secure-mark-ios.zip"
    fi
}

function build_macos() {
    if [ "$IS_MACOS" = false ]; then
        echo "[SKIP] macOS build requires macOS."
        return
    fi
    VERSION_LINE=$(grep "version: " pubspec.yaml)
    VERSION_NAME=$(echo $VERSION_LINE | cut -d' ' -f2 | cut -d'+' -f1)
    BUILD_NUMBER=$(echo $VERSION_LINE | cut -d'+' -f2)
    echo "[INFO] Building Release macOS v$VERSION_NAME+$BUILD_NUMBER..."
    $FLUTTER_PATH build macos --release --build-name=$VERSION_NAME --build-number=$BUILD_NUMBER
    
    if [ -d "build/macos/Build/Products/Release/SecureMark.app" ]; then
        echo "[INFO] Packaging macOS SecureMark.app into ZIP..."
        cd build/macos/Build/Products/Release
        zip -r ../../../../../secure-mark-macos.zip SecureMark.app > /dev/null
        cd ../../../../..
        echo "[SUCCESS] macOS build packaged at secure-mark-macos.zip"
    fi
}

function build_windows() {
    if [ "$IS_WINDOWS" = false ]; then
        echo "[SKIP] Windows build requires Windows environment."
        return
    fi
    VERSION_LINE=$(grep "version: " pubspec.yaml)
    VERSION_NAME=$(echo $VERSION_LINE | cut -d' ' -f2 | cut -d'+' -f1)
    BUILD_NUMBER=$(echo $VERSION_LINE | cut -d'+' -f2)
    echo "[INFO] Building Release Windows v$VERSION_NAME+$BUILD_NUMBER..."
    $FLUTTER_PATH build windows --release --build-name=$VERSION_NAME --build-number=$BUILD_NUMBER
    
    if [ -d "build/windows/x64/runner/Release" ]; then
        echo "[INFO] Packaging Windows build into ZIP..."
        powershell.exe -Command "Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath secure-mark-windows.zip -Force"
        echo "[SUCCESS] Windows build packaged at secure-mark-windows.zip"
    fi
}

function verify_apk() {
    if [ -f "$APK_PATH" ]; then
        echo "[INFO] Verifying APK signature..."
        $APKSIGNER_PATH verify --print-certs "$APK_PATH" | grep -E "Signer #|DN:"
        if [ $? -eq 0 ]; then
            echo "[SUCCESS] APK signature verified successfully."
        else
            echo "[ERROR] APK signature verification failed!"
        fi
    else
        echo "[WARNING] APK file not found at $APK_PATH"
    fi
}

function verify_aab() {
    if [ -f "$AAB_PATH" ]; then
        echo "[INFO] Verifying AAB signature..."
        jarsigner -verify "$AAB_PATH" | head -n 1
        jarsigner -verify -verbose -certs "$AAB_PATH" | grep "upload" > /dev/null
        if [ $? -eq 0 ]; then
            echo "[SUCCESS] AAB production signature (upload alias) confirmed."
        else
            echo "[WARNING] AAB verified but 'upload' alias not found."
        fi
    else
        echo "[WARNING] AAB file not found at $AAB_PATH"
    fi
}

function collect_artifacts() {
    VERSION_LINE=$(grep "version: " pubspec.yaml)
    VERSION_NAME=$(echo $VERSION_LINE | cut -d' ' -f2 | tr '+' '-')
    RELEASE_DIR="releases/v$VERSION_NAME"
    
    echo "[INFO] Collecting artifacts into $RELEASE_DIR..."
    mkdir -p "$RELEASE_DIR"
    
    [ -f "$APK_PATH" ] && cp "$APK_PATH" "$RELEASE_DIR/SecureMark-$VERSION_NAME.apk" && echo "[SUCCESS] APK collected."
    [ -f "$AAB_PATH" ] && cp "$AAB_PATH" "$RELEASE_DIR/SecureMark-$VERSION_NAME.aab" && echo "[SUCCESS] AAB collected."
    [ -f "secure-mark-ios.zip" ] && mv "secure-mark-ios.zip" "$RELEASE_DIR/SecureMark-$VERSION_NAME-iOS.zip" && echo "[SUCCESS] iOS ZIP collected."
    [ -f "secure-mark-macos.zip" ] && mv "secure-mark-macos.zip" "$RELEASE_DIR/SecureMark-$VERSION_NAME-macOS.zip" && echo "[SUCCESS] macOS ZIP collected."
    [ -f "secure-mark-windows.zip" ] && mv "secure-mark-windows.zip" "$RELEASE_DIR/SecureMark-$VERSION_NAME-Windows.zip" && echo "[SUCCESS] Windows ZIP collected."
}

function create_keystore() {
    if [ -f "$KEYSTORE_PATH" ]; then
        echo "[WARNING] Keystore already exists at $KEYSTORE_PATH"
        read -p "Do you want to overwrite it? (y/N): " confirm
        if [[ $confirm != [yY] ]]; then
            echo "Operation cancelled."
            return
        fi
    fi

    echo "[INFO] Generating new keystore..."
    keytool -genkey -v -keystore "$KEYSTORE_PATH" \
            -alias upload -keyalg RSA -keysize 2048 -validity 10000
    
    echo "[SUCCESS] Keystore created at $KEYSTORE_PATH"
}

function all() {
    cleanup
    update_deps
    quality_checks
    generate_assets
    increment_version
    build_apk
    build_aab
    build_ios
    build_macos
    build_windows
    echo ""
    echo "------------------------------------------------------------"
    echo "[INFO] Build Complete. Starting Verification..."
    echo "------------------------------------------------------------"
    verify_apk
    verify_aab
    collect_artifacts
    echo "------------------------------------------------------------"
    echo "[SUCCESS] Process Finished! Artifacts are in releases/ folder."
}

# Show help by default if no arguments are provided
if [ $# -eq 0 ]; then
    show_help
else
    # Allow calling specific functions passed as arguments
    for func in "$@"; do
        if [ "$func" == "help" ]; then
            show_help
        elif declare -f "$func" > /dev/null; then
            "$func"
        else
            echo "[ERROR] Function '$func' not found."
            exit 1
        fi
    done
fi
