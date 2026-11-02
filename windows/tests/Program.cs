// Cross-platform smoke tests for the Samay Windows screensaver's
// platform-portable logic. WebView2 + WinForms can't actually run on a
// Mac, but everything in this file is pure C#/file-IO and runs anywhere
// .NET 8 runs. Catches:
//   1. Argument parser regressions across every Windows .scr launch form
//   2. Theme catalog drift (id/name/count)
//   3. HTML injection — does the script tag end up in valid <head>?
//   4. clock.html sanity: track-based motion engine, both hands 45.0,
//      all 10 themes, and web/index.html kept in sync
//
// Run with:  dotnet run --project tests/UnitTests.csproj
// Exit code 0 = all green. Exit code 1 = something regressed.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace SamayTest;

// ── Copy of Themes from windows/src/Settings.cs ───────────────────────
internal static class Themes
{
    public static readonly List<(string Id, string DisplayName)> All = new()
    {
        ("studio",    "Studio"),
        ("blossom",   "Blossom"),
        ("bone",      "Bone"),
        ("porcelain", "Porcelain"),
        ("linen",     "Linen"),
        ("sand",      "Sand"),
        ("sage",      "Sage"),
        ("slate",     "Slate"),
        ("charcoal",  "Charcoal"),
        ("midnight",  "Midnight")
    };
    public static bool IsValid(string id) => All.Any(t => t.Id == id);
}

// ── Copy of ParseArgs from windows/src/Program.cs ─────────────────────
internal enum Mode { Fullscreen, Preview, Configure }
internal static class ArgParser
{
    public static (Mode, IntPtr) ParseArgs(string[] args)
    {
        if (args.Length == 0)
            return (Mode.Fullscreen, IntPtr.Zero);

        string a = args[0].Trim().ToLowerInvariant();
        if (a.StartsWith("/") || a.StartsWith("-")) a = a.Substring(1);

        IntPtr parent = IntPtr.Zero;
        int colon = a.IndexOf(':');
        if (colon > 0)
        {
            var hStr = a.Substring(colon + 1);
            if (long.TryParse(hStr, out var h)) parent = new IntPtr(h);
            a = a.Substring(0, colon);
        }

        char first = a.Length > 0 ? a[0] : 's';
        switch (first)
        {
            case 's': return (Mode.Fullscreen, IntPtr.Zero);
            case 'p':
                if (parent == IntPtr.Zero && args.Length > 1 &&
                    long.TryParse(args[1], out var ph))
                    parent = new IntPtr(ph);
                return (Mode.Preview, parent);
            case 'c': return (Mode.Configure, parent);
            case 'a': return (Mode.Configure, parent);
            default:  return (Mode.Fullscreen, IntPtr.Zero);
        }
    }
}

// ── Copy of HTML injection logic from ScreensaverForm.BuildHtml ───────
internal static class HtmlInjector
{
    public static string Inject(string html, string motion, bool format24, string theme)
    {
        var inject = $@"<script>
  window.__cc_motion   = ""{Escape(motion)}"";
  window.__cc_format24 = {(format24 ? "true" : "false")};
  window.__cc_theme    = ""{Escape(theme)}"";
</script>";
        var headEnd = html.IndexOf("</head>", StringComparison.OrdinalIgnoreCase);
        if (headEnd < 0) return inject + html;
        return html.Substring(0, headEnd) + inject + html.Substring(headEnd);
    }
    private static string Escape(string s) => s.Replace("\"", "\\\"");
}

// ── Test runner ───────────────────────────────────────────────────────
class TestRunner
{
    static int _pass = 0, _fail = 0;
    static List<string> _failures = new();

    static void Assert(bool cond, string label)
    {
        if (cond) { _pass++; Console.WriteLine($"  ✓ {label}"); }
        else      { _fail++; _failures.Add(label); Console.WriteLine($"  ✗ {label}"); }
    }

    static int Main()
    {
        Console.WriteLine("== Argument parser ==");
        // Every canonical Windows .scr invocation form
        var cases = new (string[] args, Mode expectedMode, long expectedParent)[]
        {
            (Array.Empty<string>(),      Mode.Fullscreen, 0),       // double-click
            (new[] {"/s"},               Mode.Fullscreen, 0),       // OS auto-launch
            (new[] {"/S"},               Mode.Fullscreen, 0),       // case-insensitive
            (new[] {"-s"},               Mode.Fullscreen, 0),       // dash form
            (new[] {"/c"},               Mode.Configure,  0),       // right-click → Configure
            (new[] {"/c:65432"},         Mode.Configure,  65432),   // Configure with parent HWND
            (new[] {"/p", "12345"},      Mode.Preview,    12345),   // Settings dialog thumbnail
            (new[] {"/p:99999"},         Mode.Preview,    99999),   // Alt form
            (new[] {"/a:111"},           Mode.Configure,  111),     // legacy XP password mode
            (new[] {"unknown"},          Mode.Fullscreen, 0),       // garbage → fullscreen
        };
        foreach (var (args, expMode, expParent) in cases)
        {
            var (mode, parent) = ArgParser.ParseArgs(args);
            var argStr = args.Length == 0 ? "(no args)" : string.Join(" ", args);
            Assert(mode == expMode && parent.ToInt64() == expParent,
                $"`{argStr}` → {mode}, parent={parent.ToInt64()} (expected {expMode}, {expParent})");
        }

        Console.WriteLine();
        Console.WriteLine("== Theme catalog ==");
        Assert(Themes.All.Count == 10, $"theme count = 10 (got {Themes.All.Count})");
        var expectedIds = new[] {
            "studio","blossom","bone","porcelain","linen",
            "sand","sage","slate","charcoal","midnight"
        };
        var actualIds = Themes.All.Select(t => t.Id).ToArray();
        Assert(expectedIds.SequenceEqual(actualIds), "theme order matches expected sequence");
        Assert(Themes.IsValid("studio"),  "IsValid(\"studio\") = true");
        Assert(Themes.IsValid("blossom"), "IsValid(\"blossom\") = true");
        Assert(!Themes.IsValid("teal"),   "IsValid(\"teal\") = false");
        Assert(!Themes.IsValid(""),       "IsValid(\"\") = false");

        Console.WriteLine();
        Console.WriteLine("== HTML injection ==");
        var sample = "<!doctype html><html><head><title>x</title></head><body></body></html>";
        var injected = HtmlInjector.Inject(sample, "waves", false, "blossom");
        Assert(injected.Contains("window.__cc_motion   = \"waves\""), "motion injected");
        Assert(injected.Contains("window.__cc_format24 = false"),    "format24=false injected");
        Assert(injected.Contains("window.__cc_theme    = \"blossom\""), "theme injected");
        Assert(injected.IndexOf("<script>") < injected.IndexOf("</head>"),
            "script appears before </head>");
        Assert(injected.Length > sample.Length, "injected html is longer than original");

        var injected2 = HtmlInjector.Inject(sample, "lazy", true, "studio");
        Assert(injected2.Contains("window.__cc_format24 = true"), "format24=true injected");

        var noHead = "<html>foo</html>";
        var injected3 = HtmlInjector.Inject(noHead, "fun", false, "midnight");
        Assert(injected3.Contains("window.__cc_motion") && injected3.Contains("foo"),
            "missing </head> still injects + preserves body");

        // ── clock.html sanity ────────────────────────────────────────
        // Read the actual checked-in resource. These tests prevent silent
        // regressions to the engine fixes when someone re-syncs from the
        // Mac side without remembering to bring forward critical fixes.
        Console.WriteLine();
        Console.WriteLine("== clock.html sanity ==");
        var here = Path.GetDirectoryName(typeof(TestRunner).Assembly.Location)!;
        // Walk up to find the project root, then locate the resource.
        string? projRoot = here;
        for (int i = 0; i < 6 && projRoot != null; i++)
        {
            if (File.Exists(Path.Combine(projRoot, "build.sh")) &&
                Directory.Exists(Path.Combine(projRoot, "src")))
                break;
            projRoot = Path.GetDirectoryName(projRoot);
        }
        var clockPath = Path.Combine(projRoot ?? "", "src", "Resources", "clock.html");
        Assert(File.Exists(clockPath), $"clock.html exists at {clockPath}");

        if (File.Exists(clockPath))
        {
            var html = File.ReadAllText(clockPath);
            // The animation engine must have all 10 themes
            foreach (var id in expectedIds)
                Assert(html.Contains($"{id}:"), $"clock.html has theme '{id}'");
            // Hand length parity with Mac (both arms 45 px since "equal length" change)
            Assert(html.Contains("HOUR_LEN = 45.0"),
                "clock.html HOUR_LEN = 45.0 (not legacy 40.5)");
            Assert(html.Contains("MIN_LEN  = 45.0") || html.Contains("MIN_LEN = 45.0"),
                "clock.html MIN_LEN = 45.0");
            // The motion engine works from per-hand tracks and the clock, not
            // from timers: a new minute replaces every track, so nothing from
            // the previous minute can fire late.
            Assert(html.Contains("function moveTo"), "clock.html has moveTo (track-based engine)");
            Assert(html.Contains("function angleOn"), "clock.html works out angles from tracks");
            Assert(!html.Contains("setTimeout"), "clock.html schedules no motion timers");
            Assert(html.Contains("const GLYPHS"), "clock.html has the digit glyph table");
            foreach (var mode in new[] { "waves", "lazy", "fun" })
                Assert(html.Contains($"{mode}:"), $"clock.html has motion '{mode}'");
            // The browser copy must match the embedded page.
            var webCopy = Path.Combine(projRoot ?? "", "..", "web", "index.html");
            Assert(File.Exists(webCopy) && File.ReadAllText(webCopy) == html,
                "web/index.html is an exact copy of clock.html (run web/sync.sh)");
            // The injected globals the C# host sets must be referenced
            Assert(html.Contains("window.__cc_motion"),   "clock.html reads window.__cc_motion");
            Assert(html.Contains("window.__cc_theme"),    "clock.html reads window.__cc_theme");
            Assert(html.Contains("window.__cc_format24"), "clock.html reads window.__cc_format24");
        }

        Console.WriteLine();
        Console.WriteLine($"-- {_pass} passed, {_fail} failed --");
        if (_fail > 0)
        {
            Console.WriteLine();
            Console.WriteLine("Failures:");
            foreach (var f in _failures) Console.WriteLine($"  ✗ {f}");
            return 1;
        }
        return 0;
    }
}
