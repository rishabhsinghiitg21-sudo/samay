// Samay Windows screensaver — preferences.
// Settings live in HKEY_CURRENT_USER\Software\Samay so each Windows user
// can have their own theme/motion/format choice. The values match the
// Mac version's keys exactly (motion, theme, format24h) so they're easy
// to reason about across platforms.

using System.Collections.Generic;
using System.Linq;
using Microsoft.Win32;

namespace Samay;

internal class Settings
{
    public string Theme     { get; set; } = "studio";
    public string Motion    { get; set; } = "waves";
    public bool   Format24h { get; set; } = false;

    private const string KeyPath = @"Software\Samay";

    public static Settings Load()
    {
        var s = new Settings();
        using var key = Registry.CurrentUser.OpenSubKey(KeyPath);
        if (key != null)
        {
            if (key.GetValue("theme") is string t && Themes.IsValid(t))
                s.Theme = t;
            if (key.GetValue("motion") is string m &&
                (m == "waves" || m == "lazy" || m == "fun"))
                s.Motion = m;
            if (key.GetValue("format24h") is int f)
                s.Format24h = (f != 0);
        }
        return s;
    }

    public void Save()
    {
        using var key = Registry.CurrentUser.CreateSubKey(KeyPath);
        key.SetValue("theme",     Theme);
        key.SetValue("motion",    Motion);
        key.SetValue("format24h", Format24h ? 1 : 0, RegistryValueKind.DWord);
    }
}

internal static class Themes
{
    /// <summary>
    /// Theme catalog. Order here is the order shown in the configure
    /// dropdown. Display names are user-facing; ids are the keys passed
    /// to clock.html via window.__cc_theme.
    /// </summary>
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
