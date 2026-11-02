# Samay for macOS

A native screensaver. Every dial and hand is a Core Animation layer, and each minute's move plays as one keyframe animation per hand. An earlier version showed a web page inside the screensaver, but macOS Tahoe stopped drawing web content there, so this one is drawn natively.

## Build

Needs the Xcode command-line tools (`xcode-select --install`). No Xcode project and no signing team.

    cd mac
    ./build.sh            # → build/Samay.saver
    ./build.sh some/dir   # → some/dir/Samay.saver

## Install

Double-click `build/Samay.saver` and macOS offers to install it. Or copy it yourself:

    cp -R build/Samay.saver ~/Library/Screen\ Savers/

Then open System Settings → Screen Saver, pick **Samay**, and click **Options…** for the theme, motion and time format.

A build you make yourself runs straight away. A copy downloaded from the internet is quarantined, and macOS has no "Open Anyway" for screensavers, so clear the flag once:

    xattr -dr com.apple.quarantine ~/Library/Screen\ Savers/Samay.saver

## Uninstall

    rm -rf ~/Library/Screen\ Savers/Samay.saver

## Files

- `sources/SamayView.swift` — the whole screensaver: layers, themes, sun shadow, motion engine, options sheet.
- `Info.plist` — bundle metadata. The bundle id is `com.rishabh.samay`; the same string names the preferences domain in `SamayView.swift` (`defaultsName`), so keep the two in step.
- `assets/` — the System Settings thumbnails, drawn by `scripts/snapshot/main.swift`.
- `scripts/snapshot/main.swift` — draws the view offscreen to a PNG at a fixed time and theme, or at any moment of a move (to check the motion against the web version). Build steps are at the top of the file.
- `release/make_release.sh` — builds, signs ad hoc, and wraps the saver in `dist/Samay-<ver>.dmg` for GitHub Releases. Not notarised.
