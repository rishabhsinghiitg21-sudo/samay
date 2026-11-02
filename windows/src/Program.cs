// Samay Windows screensaver — entry point.
// Implements the standard .scr command-line contract Windows uses to
// launch screensavers:
//   /s            — fullscreen mode (the actual screensaver)
//   /p HWND       — preview thumbnail in the Screen Saver settings dialog
//   /c            — open the configure dialog
//   /c:HWND       — open the configure dialog parented to HWND
// No-args (e.g. double-click from Explorer) defaults to /s, matching how
// Windows itself launches screensavers.

using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace Samay;

internal static class Program
{
    enum Mode { Fullscreen, Preview, Configure }

    [STAThread]
    static void Main(string[] args)
    {
        // Per-monitor v2 DPI awareness (also declared in app.manifest as
        // belt + suspenders for older WinForms loaders).
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        var (mode, parent) = ParseArgs(args);

        switch (mode)
        {
            case Mode.Fullscreen: RunFullscreen(); break;
            case Mode.Preview:    RunPreview(parent); break;
            case Mode.Configure:  RunConfigure(); break;
        }
    }

    /// <summary>
    /// Tease the screensaver mode and parent HWND out of argv. Tolerates
    /// both `/p HWND` and `/p:HWND`, both `/c` and `/c:HWND`, both
    /// uppercase and lowercase, and bare `s` / `p` / `c`.
    /// </summary>
    static (Mode, IntPtr) ParseArgs(string[] args)
    {
        if (args.Length == 0)
            return (Mode.Fullscreen, IntPtr.Zero);

        string a = args[0].Trim().ToLowerInvariant();
        if (a.StartsWith("/") || a.StartsWith("-"))
            a = a.Substring(1);

        IntPtr parent = IntPtr.Zero;

        // Split off `:HWND` if present
        int colon = a.IndexOf(':');
        if (colon > 0)
        {
            var hStr = a.Substring(colon + 1);
            if (long.TryParse(hStr, out var h))
                parent = new IntPtr(h);
            a = a.Substring(0, colon);
        }

        char first = a.Length > 0 ? a[0] : 's';
        switch (first)
        {
            case 's':
                return (Mode.Fullscreen, IntPtr.Zero);

            case 'p':
                // Standard form: `/p HWND` — HWND is args[1]
                if (parent == IntPtr.Zero && args.Length > 1 &&
                    long.TryParse(args[1], out var ph))
                    parent = new IntPtr(ph);
                return (Mode.Preview, parent);

            case 'c':
                return (Mode.Configure, parent);

            case 'a':
                // Win XP-era "set password" mode. Not used on modern
                // Windows; treat as configure so we don't crash.
                return (Mode.Configure, parent);

            default:
                return (Mode.Fullscreen, IntPtr.Zero);
        }
    }

    /// <summary>
    /// Run the screensaver fullscreen. Creates one ScreensaverForm per
    /// monitor and runs them all in parallel — same content on each
    /// screen, like a synchronized wallpaper. The first form to receive
    /// input closes everything.
    /// </summary>
    static void RunFullscreen()
    {
        var forms = new List<ScreensaverForm>();
        var ctx = new ApplicationContext();

        bool exiting = false;
        void exitAll(object? sender, EventArgs e)
        {
            if (exiting) return;
            exiting = true;
            foreach (var f in forms)
            {
                if (!f.IsDisposed) f.Close();
            }
            ctx.ExitThread();
        }

        foreach (var screen in Screen.AllScreens)
        {
            var f = new ScreensaverForm(screen.Bounds);
            f.ExitRequested += exitAll;
            forms.Add(f);
            f.Show();
        }

        Application.Run(ctx);
    }

    /// <summary>
    /// Draw the small live preview inside the Screen Saver settings
    /// dialog's thumbnail. Windows passes the parent HWND as a
    /// command-line argument; we reparent our form into it.
    /// </summary>
    static void RunPreview(IntPtr parent)
    {
        if (parent == IntPtr.Zero) return; // nothing to draw into
        var f = new ScreensaverForm(parent);
        Application.Run(f);
    }

    /// <summary>
    /// Open the configure dialog (theme / motion / format).
    /// </summary>
    static void RunConfigure()
    {
        Application.Run(new ConfigForm());
    }
}
