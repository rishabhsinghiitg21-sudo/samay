# Samay for Windows

Twenty-four small dials, two hands each, turn together to spell out the current time, then settle. Ten themes that shift between day and night palettes, and a recess shadow that follows the sun by day and the moon by night.

The Windows build is a small WinForms host with a WebView2 that runs `src/Resources/clock.html`, the same page as `web/index.html`.

> Not yet tested on a real Windows PC. It builds (cross-compiled from a Mac) and its unit tests pass.

---

## Install

1. Right-click `Samay.scr` and pick **Install**.
2. Windows opens the Screen Saver settings dialog with **Samay** selected.
3. Click **Settings...** to choose a theme, motion, and time format.
4. Click **Preview** to see it run.
5. Hit **OK**. Samay runs whenever your machine sits idle.

If Windows SmartScreen says "Windows protected your PC", click **More info** → **Run anyway**. The build isn't signed with a code-signing certificate, so Windows warns once.

## Uninstall

Right-click the `.scr` file and choose **Delete**. Or run this in a Command Prompt:

```
del "%USERPROFILE%\Downloads\Samay.scr"
```

(Or wherever you saved it.) That's it. There's no installer and nothing else to clean up.

## Options

Right-click your desktop → Personalize → Lock screen → scroll to **Screen saver** → click **Settings...**

You'll see:

- **Theme** — Studio, Blossom, Bone, Porcelain, Linen, Sand, Sage, Slate, Charcoal, Midnight.
- **Motion** — Waves (default), Lazy, Fun.
- **Format** — 12-hour or 24-hour.

Every theme automatically uses a softer day palette from 6 am to 8 pm and a darker night palette from 8 pm to 6 am. No toggle needed.

### Themes

| Theme     | Day palette                  | Night palette                |
|-----------|------------------------------|------------------------------|
| Studio    | white panel, black hands     | bone-gray panel, black hands |
| Blossom   | hot pink panel, magenta hands| deep maroon, light pink hands|
| Bone      | warm cream, dark brown hands | dark walnut, cream hands     |
| Porcelain | cool white, navy hands       | navy panel, ice hands        |
| Linen     | soft beige, charcoal hands   | dark taupe, beige hands      |
| Sand      | warm tan, dark espresso hands| espresso panel, tan hands    |
| Sage      | muted green, deep green hands| forest green, sage hands     |
| Slate     | gray, dark gray hands        | charcoal, light slate hands  |
| Charcoal  | dark gray, cream hands       | near-black, cream hands      |
| Midnight  | deep gray, cream hands       | near-black, cream hands      |

### Motion modes

- **Waves** — column by column, every dial turns into one diagonal line, spins it a full turn, then opens into the time. A ripple runs left to right. About 20 seconds.
- **Lazy** — only the dials whose digit changed move, the short way round. About 16 seconds, gentle.
- **Fun** — every hand makes an extra full turn, the two hands of a dial in opposite directions, then lands. About 16 seconds.

### Multi-monitor

Each monitor gets its own panel, properly sized. Same content on each, like a synchronized wallpaper.

## Requirements

- **Windows 10 or 11**, 64-bit.
- **Microsoft Edge / WebView2 runtime** — preinstalled on every Windows 10/11 machine since 2021. Nothing to install separately.

## Build from source

Needs the .NET 8 SDK or newer. It cross-compiles from macOS or Linux too.

```
cd windows
./build.sh                                    # → out/Samay.scr
dotnet run --project tests/UnitTests.csproj   # unit tests
./release/make_release.sh                     # tests + build + dist/Samay-<ver>-windows.zip
```

Settings live in the registry under `HKEY_CURRENT_USER\Software\Samay`.
