// Samay Windows screensaver — fullscreen / preview window.
// One form per monitor. Each form embeds a WebView2 that loads the same
// clock.html the Mac version uses, so the visual contract is identical
// across platforms. Any keypress, mouse click, or significant mouse
// movement closes the form (and tears down the whole app via the
// ExitRequested event).

using System;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace Samay;

internal class ScreensaverForm : Form
{
    private readonly bool _isPreview;
    private readonly WebView2 _web = new();
    private Point? _lastMouse;

    public event EventHandler? ExitRequested;

    /// <summary>Fullscreen on the given monitor.</summary>
    public ScreensaverForm(Rectangle screenBounds)
    {
        _isPreview = false;
        InitCommon();
        FormBorderStyle = FormBorderStyle.None;
        TopMost         = true;
        StartPosition   = FormStartPosition.Manual;
        Bounds          = screenBounds;
        ShowInTaskbar   = false;
        Cursor.Hide();
        Cursor          = Cursors.Default; // suppress default arrow
    }

    /// <summary>Preview thumbnail mode: reparent into the HWND Windows gives us.</summary>
    public ScreensaverForm(IntPtr parentHwnd)
    {
        _isPreview = true;
        InitCommon();
        FormBorderStyle = FormBorderStyle.None;
        StartPosition   = FormStartPosition.Manual;
        ShowInTaskbar   = false;

        // Reparenting must happen after the form has a real HWND.
        HandleCreated += (_, _) =>
        {
            // Switch our window style from popup to child
            var style = (long)GetWindowLongPtr(Handle, GWL_STYLE);
            style = (style & ~WS_POPUP) | WS_CHILD;
            SetWindowLongPtr(Handle, GWL_STYLE, new IntPtr(style));

            SetParent(Handle, parentHwnd);

            // Size to fit the parent's client area
            if (GetClientRect(parentHwnd, out var rc))
            {
                Bounds = new Rectangle(0, 0, rc.Right - rc.Left, rc.Bottom - rc.Top);
            }
        };
    }

    private void InitCommon()
    {
        Text         = "Samay";
        BackColor    = Color.Black;
        DoubleBuffered = true;

        _web.Dock = DockStyle.Fill;
        _web.DefaultBackgroundColor = Color.Black;
        Controls.Add(_web);

        Load   += async (_, _) => await SetupWebView();
        FormClosing += (_, _) => { if (!_isPreview) Cursor.Show(); };

        if (!_isPreview)
        {
            // Any input ends the screensaver. The WebView2 fills the form
            // and takes the keyboard and mouse itself, so clock.html posts
            // a message on any input (see SetupWebView). These form hooks
            // only cover the moment before the page has loaded.
            KeyDown    += (_, _) => RequestExit();
            KeyPress   += (_, _) => RequestExit();
            MouseDown  += (_, _) => RequestExit();
            MouseMove  += OnMouseMove;
        }
    }

    private void RequestExit()
    {
        ExitRequested?.Invoke(this, EventArgs.Empty);
        if (!IsDisposed) Close();
    }

    private void OnMouseMove(object? sender, MouseEventArgs e)
    {
        // Ignore the very first MouseMove (it can fire on form show)
        // and tiny jitters under 5 px to avoid false triggers.
        if (_lastMouse is null) { _lastMouse = e.Location; return; }
        var dx = Math.Abs(e.Location.X - _lastMouse.Value.X);
        var dy = Math.Abs(e.Location.Y - _lastMouse.Value.Y);
        if (dx > 5 || dy > 5) RequestExit();
    }

    /// <summary>
    /// Boots WebView2: creates a private user-data folder under LocalAppData
    /// (so it doesn't try to write to a system-wide location), strips the
    /// usual chrome (zoom, context menu, dev tools), and loads our HTML
    /// with the user's preferences injected.
    /// </summary>
    private async Task SetupWebView()
    {
        try
        {
            var dataFolder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Samay", "WebView2");
            Directory.CreateDirectory(dataFolder);

            var env = await CoreWebView2Environment.CreateAsync(null, dataFolder);
            await _web.EnsureCoreWebView2Async(env);

            var s = _web.CoreWebView2.Settings;
            s.AreDefaultContextMenusEnabled = false;
            s.AreDevToolsEnabled            = false;
            s.IsZoomControlEnabled          = false;
            s.IsStatusBarEnabled            = false;
            s.IsBuiltInErrorPageEnabled     = false;

            // clock.html posts a message on any key, click or real mouse move.
            if (!_isPreview)
                _web.CoreWebView2.WebMessageReceived += (_, _) => RequestExit();

            _web.NavigateToString(BuildHtml());
        }
        catch (Exception ex)
        {
            // If WebView2 isn't available for some reason, fall back to
            // a plain black screen rather than crashing.
            BackColor = Color.Black;
            Console.Error.WriteLine($"WebView2 init failed: {ex.Message}");
        }
    }

    /// <summary>
    /// Reads the embedded clock.html resource and prepends a tiny script
    /// tag that sets window.__cc_motion / __cc_theme / __cc_format24 so
    /// the page picks up the user's saved preferences on first paint.
    /// </summary>
    private static string BuildHtml()
    {
        var asm  = typeof(Program).Assembly;
        var resName = asm.GetManifestResourceNames()
            .FirstOrDefault(n => n.EndsWith("clock.html", StringComparison.Ordinal));
        if (resName == null)
            return "<html><body style='background:#000;'></body></html>";

        using var stream = asm.GetManifestResourceStream(resName)!;
        using var reader = new StreamReader(stream);
        var html = reader.ReadToEnd();

        var s = Settings.Load();
        var inject = $@"<script>
  window.__cc_motion   = ""{Escape(s.Motion)}"";
  window.__cc_format24 = {(s.Format24h ? "true" : "false")};
  window.__cc_theme    = ""{Escape(s.Theme)}"";
</script>";

        var headEnd = html.IndexOf("</head>", StringComparison.OrdinalIgnoreCase);
        if (headEnd < 0) return inject + html;
        return html.Substring(0, headEnd) + inject + html.Substring(headEnd);
    }

    private static string Escape(string s) => s.Replace("\"", "\\\"");

    // ── P/Invoke for parent reparenting in preview mode ──────────────

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW", SetLastError = true)]
    static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
    static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    const int  GWL_STYLE = -16;
    const long WS_POPUP  = 0x80000000L;
    const long WS_CHILD  = 0x40000000L;

    [StructLayout(LayoutKind.Sequential)]
    struct RECT { public int Left, Top, Right, Bottom; }
}
