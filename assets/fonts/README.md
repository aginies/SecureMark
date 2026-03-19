# Custom Fonts Setup

## How to Add Your Own Fonts

You can add custom TrueType Font (.ttf) or OpenType Font (.otf) files to this directory to extend the font options in WatermarkApp.

### Step 1: Copy Font Files

Copy your font files from your system to this directory. For example:

**On Linux/macOS:**
```bash
# System fonts are usually in:
# /usr/share/fonts/ (Linux)
# /System/Library/Fonts/ (macOS)
# ~/.local/share/fonts/ (Linux user fonts)

# Example: Copy Roboto font
cp /usr/share/fonts/truetype/dejavu/Roboto-Regular.ttf assets/fonts/
cp /usr/share/fonts/truetype/dejavu/Roboto-Bold.ttf assets/fonts/
```

**On Windows:**
```cmd
# System fonts are in: C:\Windows\Fonts\
# Example: Copy fonts to your project
copy "C:\Windows\Fonts\Roboto-Regular.ttf" assets\fonts\
copy "C:\Windows\Fonts\Roboto-Bold.ttf" assets\fonts\
```

### Step 2: Required Font Files

For each custom font family, you should include at least:
- `FontName-Regular.ttf` (normal weight)
- `FontName-Bold.ttf` (bold weight) - optional but recommended

### Step 3: Update Font Configuration

The app is already configured for these custom fonts:

- **CustomRoboto**: Place `Roboto-Regular.ttf` and `Roboto-Bold.ttf` here
- **CustomOpenSans**: Place `OpenSans-Regular.ttf` and `OpenSans-Bold.ttf` here  
- **CustomLato**: Place `Lato-Regular.ttf` and `Lato-Bold.ttf` here
- **CustomMontserrat**: Place `Montserrat-Regular.ttf` and `Montserrat-Bold.ttf` here

### Step 4: Adding New Font Families

To add completely new font families beyond the pre-configured ones:

1. **Copy the font files** to this directory
2. **Update `pubspec.yaml`** - add the new font family:
   ```yaml
   fonts:
     - family: YourCustomFont
       fonts:
         - asset: assets/fonts/YourFont-Regular.ttf
         - asset: assets/fonts/YourFont-Bold.ttf
           weight: 700
   ```
3. **Update `lib/font_manager.dart`** - add the new enum entry:
   ```dart
   yourCustomFont('YourCustomFont', 'Your Custom Font (TTF)', false, FontSource.asset),
   ```

### Font File Naming Convention

Use this naming pattern for consistency:
- `FontFamily-Regular.ttf` (weight: 400)
- `FontFamily-Bold.ttf` (weight: 700)
- `FontFamily-Light.ttf` (weight: 300) - if available
- `FontFamily-Medium.ttf` (weight: 500) - if available

### Popular Free Fonts Sources

- **Google Fonts**: https://fonts.google.com/ (download TTF files)
- **Font Squirrel**: https://www.fontsquirrel.com/ (free commercial fonts)
- **System Fonts**: Use fonts already installed on your system

### Examples

After adding font files, your directory structure should look like:
```
assets/fonts/
├── Roboto-Regular.ttf
├── Roboto-Bold.ttf
├── OpenSans-Regular.ttf
├── OpenSans-Bold.ttf
├── Lato-Regular.ttf
├── Lato-Bold.ttf
├── Montserrat-Regular.ttf
├── Montserrat-Bold.ttf
└── README.md (this file)
```

### Notes

- **Font Licensing**: Ensure you have proper licensing for any fonts you add
- **File Size**: TTF files can be large (1-2MB each) - this affects app size
- **Watermark Rendering**: Custom fonts will show in UI previews. Actual watermark rendering currently uses bitmap fallback for performance, but this may be enhanced in future versions
- **Platform Support**: TTF/OTF fonts work across all Flutter platforms (iOS, Android, Windows, macOS, Linux, Web)

After adding fonts and rebuilding the app, the new custom fonts will appear in the font selection dropdown in Expert Settings!