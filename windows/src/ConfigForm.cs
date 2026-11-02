// Samay Windows screensaver — configure dialog.
// Mirrors the macOS configure sheet: Theme dropdown, Motion segmented
// (Waves / Lazy / Fun, Waves first because it's the default), and
// Format radio (12-hour / 24-hour). Values persist to HKCU\Software\Samay
// via Settings.Save().

using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace Samay;

internal class ConfigForm : Form
{
    private readonly ComboBox    _themeBox    = new();
    private readonly RadioButton _motionWaves = new() { Text = "Waves" };
    private readonly RadioButton _motionLazy  = new() { Text = "Lazy"  };
    private readonly RadioButton _motionFun   = new() { Text = "Fun"   };
    private readonly RadioButton _format12    = new() { Text = "12-hour" };
    private readonly RadioButton _format24    = new() { Text = "24-hour" };

    public ConfigForm()
    {
        Text            = "Samay";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox     = false;
        MinimizeBox     = false;
        StartPosition   = FormStartPosition.CenterScreen;
        ClientSize      = new Size(420, 240);
        ShowInTaskbar   = true;
        Font            = new Font("Segoe UI", 9f);

        var current = Settings.Load();

        // ── Theme row ───────────────────────────────────────────
        var themeLabel = new Label {
            Text     = "Theme",
            Location = new Point(24, 28),
            AutoSize = true
        };
        _themeBox.DropDownStyle = ComboBoxStyle.DropDownList;
        _themeBox.Location      = new Point(110, 24);
        _themeBox.Width         = 280;
        foreach (var (id, name) in Themes.All)
            _themeBox.Items.Add(new ThemeItem(id, name));
        var selectedThemeIndex = Themes.All.FindIndex(t => t.Id == current.Theme);
        _themeBox.SelectedIndex = selectedThemeIndex >= 0 ? selectedThemeIndex : 0;

        // ── Motion row ──────────────────────────────────────────
        var motionLabel = new Label {
            Text     = "Motion",
            Location = new Point(24, 76),
            AutoSize = true
        };
        _motionWaves.Location = new Point(110, 72); _motionWaves.AutoSize = true;
        _motionLazy .Location = new Point(190, 72); _motionLazy .AutoSize = true;
        _motionFun  .Location = new Point(270, 72); _motionFun  .AutoSize = true;
        switch (current.Motion)
        {
            case "lazy": _motionLazy.Checked = true; break;
            case "fun":  _motionFun .Checked = true; break;
            default:     _motionWaves.Checked = true; break;
        }

        // ── Format row ──────────────────────────────────────────
        var formatLabel = new Label {
            Text     = "Format",
            Location = new Point(24, 124),
            AutoSize = true
        };
        _format12.Location = new Point(110, 120); _format12.AutoSize = true;
        _format24.Location = new Point(220, 120); _format24.AutoSize = true;
        if (current.Format24h) _format24.Checked = true;
        else                    _format12.Checked = true;

        // ── Footer hint + buttons ───────────────────────────────
        var hint = new Label {
            Text = "Themes shift between day and night palettes automatically.",
            Location = new Point(24, 168),
            AutoSize = true,
            ForeColor = SystemColors.GrayText
        };

        var ok = new Button {
            Text         = "OK",
            Location     = new Point(304, 196),
            Size         = new Size(86, 30),
            DialogResult = DialogResult.OK
        };
        ok.Click += OnOk;

        var cancel = new Button {
            Text         = "Cancel",
            Location     = new Point(208, 196),
            Size         = new Size(86, 30),
            DialogResult = DialogResult.Cancel
        };
        cancel.Click += (_, _) => Close();

        AcceptButton = ok;
        CancelButton = cancel;

        Controls.AddRange(new Control[] {
            themeLabel, _themeBox,
            motionLabel, _motionWaves, _motionLazy, _motionFun,
            formatLabel, _format12, _format24,
            hint, ok, cancel
        });
    }

    private void OnOk(object? sender, EventArgs e)
    {
        var item = _themeBox.SelectedItem as ThemeItem;
        var s = new Settings
        {
            Theme     = item?.Id ?? "studio",
            Motion    = _motionLazy.Checked ? "lazy" :
                        _motionFun .Checked ? "fun"  : "waves",
            Format24h = _format24.Checked
        };
        s.Save();
        Close();
    }

    private record ThemeItem(string Id, string DisplayName)
    {
        public override string ToString() => DisplayName;
    }
}
