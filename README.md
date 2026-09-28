# EPUB Quick Look

[Tiếng Việt](README.vi.md)

EPUB Quick Look adds a Finder Quick Look preview for `.epub` books. Select a book and press **Space** to see its title, author, chapters, and images. The app also has a simple EPUB reading window. It is built with Swift, AppKit, and Apple's Quick Look preview extension API, without third-party libraries.

## Compatibility

- Tested on an Apple Silicon Mac with macOS 27 and Xcode 27.
- The Xcode project has a macOS 15.0 deployment target. Older systems have not been tested.
- The preview supports unencrypted EPUB files. DRM-protected books are not supported.

## Install from a release

Download either `EPUB-Quick-Look-macOS.dmg` or `EPUB-Quick-Look-macOS.zip` from [GitHub Releases](https://github.com/thangnt/epub-quicklook-macos/releases/latest). Both contain the same app.

**DMG:** Open the disk image, drag `EPUB Quick Look.app` onto the **Applications** shortcut, then eject the disk image.

**ZIP:** Unzip the archive and copy `EPUB Quick Look.app` to `/Applications`.

Open the app once from Applications to let macOS register its Quick Look extension. Then select any `.epub` file in Finder and press **Space**. The app does not need to stay open.

The release is signed ad hoc and is **not notarized by Apple**. On another Mac, macOS may block its first launch. If you trust this release, try opening the app, then use **System Settings → Privacy & Security → Open Anyway** and follow the prompts. See [Apple's instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). Do not disable Gatekeeper system-wide.

## Use

- **Finder preview:** Select one `.epub` file and press **Space**. Press Space or Escape to close the preview.
- **Reading window:** Open `EPUB Quick Look.app`, then choose **Mở EPUB…**. You can also use **Open With → EPUB Quick Look** in Finder.

## If Finder shows only the EPUB icon

1. Confirm the app is in `/Applications` and open it once.
2. In **System Settings → General → Login Items & Extensions → Quick Look**, enable **EPUBPreview**. [Apple documents this setting](https://support.apple.com/guide/mac-help/change-login-items-extensions-settings-mtusr003/mac).
3. If another EPUB preview extension is installed, disable it temporarily and try again.
4. Run `qlmanage -r` in Terminal to refresh Quick Look, then retry Finder.

## Build from source

Use Xcode 27 on a Mac with the macOS SDK. Open `EPUBQuickLook.xcodeproj` and build the **EPUBQuickLook** scheme, or run:

```sh
xcodebuild -project EPUBQuickLook.xcodeproj \
  -scheme EPUBQuickLook -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY=- build
```

The app is written to `build/Build/Products/Release/EPUB Quick Look.app`. The project definition is `project.yml`; if you edit it, regenerate the Xcode project with `xcodegen generate`.

## Limits and privacy

- For responsive previews, Quick Look shows up to the first 30 chapters, 2 MB of HTML markup, and 25 MB of images.
- PNG, JPEG, GIF, and WebP images are supported. Complex book CSS, SVG, audio, video, and scripts are not rendered. Invalid XHTML falls back to simplified text.
- Processing stays on the Mac. The app and extension do not request network access.

To uninstall, remove `EPUB Quick Look.app` from Applications. If Finder retains an old preview, run `qlmanage -r`.
