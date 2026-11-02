// Samay screensaver
// Native Cocoa / Core Animation renderer. macOS Tahoe's legacyScreenSaver
// host suspends WKWebView's WebContent process aggressively, leaving the
// view blank, so we draw the dials and hands directly with CALayers and
// animate them with keyframe animations. The motion engine matches the
// one in windows/src/Resources/clock.html (the Windows and web version).

import Cocoa
import ScreenSaver
import QuartzCore

@objc(SamayView)
public final class SamayView: ScreenSaverView {

    // MARK: - Geometry constants (panel 900 × 400, 24 dials of 90)
    private static let PANEL_W: CGFloat   = 900
    private static let PANEL_H: CGFloat   = 400
    private static let DIAL_DIAM: CGFloat = 90
    private static let GAP: CGFloat       = 10
    private static let PANEL_PAD: CGFloat = 55
    private static let HAND_W: CGFloat    = 5.4
    private static let HAND_R: CGFloat    = HAND_W / 2
    // Both hands the same length: full radius, they reach the rim, so two
    // hands from neighbouring dials read as one line.
    private static let HOUR_LEN: CGFloat  = 45.0
    private static let MIN_LEN: CGFloat   = 45.0
    private static let HUB_DIAM: CGFloat  = 5.4

    // MARK: - Themes
    fileprivate struct Palette {
        let panel: NSColor
        let floor: NSColor
        let hand:  NSColor
    }
    fileprivate struct Theme {
        let id: String
        let displayName: String
        let day:   Palette
        let night: Palette
    }

    private static let THEME_ORDER: [String] = [
        "studio", "blossom", "bone", "porcelain", "linen", "sand", "sage", "slate", "charcoal", "midnight"
    ]

    private static let THEMES: [String: Theme] = {
        func mk(_ id: String, _ name: String,
                _ dPanel: String, _ dFloor: String, _ dHand: String,
                _ nPanel: String, _ nFloor: String, _ nHand: String) -> Theme {
            return Theme(id: id, displayName: name,
                         day:   Palette(panel: hex(dPanel), floor: hex(dFloor), hand: hex(dHand)),
                         night: Palette(panel: hex(nPanel), floor: hex(nFloor), hand: hex(nHand)))
        }
        let entries: [Theme] = [
            mk("studio",    "Studio",    "#FFFFFF","#FFFFFF","#0A0A0A", "#E8E8E8","#DEDEDE","#0A0A0A"),
            mk("blossom",   "Blossom",   "#F768A0","#FACDE5","#E0218A", "#3E0F25","#5C1A3A","#FACDE5"),
            mk("bone",      "Bone",      "#F2EBDF","#FBF1D8","#3A2A1B", "#3D3022","#2A2117","#F0E2C2"),
            mk("porcelain", "Porcelain", "#F8F8F8","#FEFEFE","#1B2840", "#1B2840","#101A2C","#E8ECF5"),
            mk("linen",     "Linen",     "#EDE7DC","#F4EAD0","#2D2D2D", "#3A3530","#2A2622","#EDE7DC"),
            mk("sand",      "Sand",      "#D9C2A6","#E8D2B0","#2A1A10", "#3E2E1A","#2A1F12","#D9C2A6"),
            mk("sage",      "Sage",      "#A4B3A0","#BCCAB8","#1F2A1A", "#2C3A26","#1A2418","#BCCAB8"),
            mk("slate",     "Slate",     "#B0B5BA","#C8CCD0","#1B1F23", "#2E3236","#1F2226","#C8CCD0"),
            mk("charcoal",  "Charcoal",  "#52555A","#62656A","#EDE6D6", "#2A2C2E","#1A1C1E","#EDE6D6"),
            mk("midnight",  "Midnight",  "#26262C","#3A3A40","#EDE6D6", "#0A0A0E","#18181C","#EDE6D6")
        ]
        var dict: [String: Theme] = [:]
        for t in entries { dict[t.id] = t }
        return dict
    }()

    private static func hex(_ s: String) -> NSColor {
        var t = s; if t.hasPrefix("#") { t.removeFirst() }
        let v = UInt32(t, radix: 16) ?? 0
        return NSColor(srgbRed: CGFloat((v>>16)&0xff)/255,
                       green:   CGFloat((v>>8)&0xff)/255,
                       blue:    CGFloat(v&0xff)/255,
                       alpha:   1)
    }

    private static let THEME_NAMES: [String: String] = {
        var d: [String: String] = [:]
        for (k, v) in THEMES { d[k] = v.displayName }
        return d
    }()

    // MARK: - Glyphs
    // Each digit is 3 rows × 2 dials, and each dial lists its two hands in
    // clock degrees (0 = 12 o'clock, clockwise). Strokes run between dial
    // centres: a line to a neighbour is one hand from each. A stroke that
    // ends inside a dial is both hands on top of each other. A dial has
    // only two hands, so it can't draw a T: where a digit needs one
    // (3, 4, 6, 8, 9), one arm becomes a short stub pointing at the missing
    // join, which the eye fills in. Unused dials rest at half past seven.
    // Same table as clock.html.
    private static let U = 0.0, R = 90.0, D = 180.0, L = 270.0, REST = 225.0
    private static let GLYPHS: [[[(Double, Double)]]] = [
        /* 0 */ [[(R, D), (L, D)], [(U, D), (U, D)], [(U, R), (U, L)]],
        /* 1 */ [[(REST, REST), (D, D)], [(REST, REST), (U, D)], [(REST, REST), (U, U)]],
        /* 2 */ [[(R, R), (L, D)], [(R, D), (U, L)], [(U, R), (L, L)]],
        /* 3 */ [[(R, R), (L, D)], [(R, R), (L, D)], [(R, R), (U, L)]],
        /* 4 */ [[(D, D), (D, D)], [(U, R), (L, D)], [(REST, REST), (U, U)]],
        /* 5 */ [[(R, D), (L, L)], [(U, R), (L, D)], [(R, R), (U, L)]],
        /* 6 */ [[(R, D), (L, L)], [(U, D), (L, D)], [(U, R), (U, L)]],
        /* 7 */ [[(R, R), (L, D)], [(REST, REST), (U, D)], [(REST, REST), (U, U)]],
        /* 8 */ [[(R, D), (L, D)], [(R, D), (L, D)], [(U, R), (U, L)]],
        /* 9 */ [[(R, D), (L, D)], [(U, R), (U, D)], [(R, R), (U, L)]],
    ]

    // MARK: - User preferences (persisted via ScreenSaverDefaults)
    private static let defaultsName = "com.rishabh.samay"
    private var motion: String = "waves"        // "waves" | "lazy" | "fun"
    private var themeId: String = "studio"
    private var clockFormat24h: Bool = false

    // MARK: - Layer hierarchy
    private var panelLayer: CALayer!
    private var dialContainerLayers: [CALayer] = []
    private var dialBackdropLayers:  [CALayer] = []
    private var hourHandLayers:      [CALayer] = []
    private var minHandLayers:       [CALayer] = []
    private var hubLayers:           [CALayer] = []

    // MARK: - Engine state
    /// One track per hand: dial i → hands 2i (hour layer) and 2i + 1
    /// (minute layer). See "Motion engine" below.
    fileprivate var tracks: [Track] = []
    private var lastTime: String = ""
    private var lastMotion: String = ""
    private var lastShadowKey: String = ""
    private var lastPaletteKey: String = ""

    private var tickTimer: Timer?
    /// The panel's current scale on screen (see repositionPanel).
    private var panelScale: CGFloat = 1

    // MARK: - Lifecycle
    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private var stopObserver: NSObjectProtocol?

    private func commonInit() {
        // Core Animation plays every frame and our own timer checks the
        // clock, so the host's frame callback has nothing to do: keep it slow.
        animationTimeInterval = 1.0
        loadPrefs()
        setupLayers()
        // Since macOS 14 the host often never calls stopAnimation and keeps
        // the view alive after the screensaver ends. It does post this
        // notification, so stop then too. Not for the System Settings
        // preview, which keeps running after the full screen one ends.
        if !isPreview {
            stopObserver = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("com.apple.screensaver.willstop"),
                object: nil, queue: .main) { [weak self] _ in self?.halt() }
        }
    }

    deinit {
        tickTimer?.invalidate()
        if let o = stopObserver { DistributedNotificationCenter.default().removeObserver(o) }
    }

    // MARK: - Layer setup
    private func setupLayers() {
        // Use layer-hosting mode (assign a custom root layer) so the view
        // is guaranteed to be layer-backed regardless of when AppKit lazily
        // creates the layer. legacyScreenSaver on Tahoe has been seen to
        // skip layer creation in some cases when only `wantsLayer=true` is
        // set, leaving the view drawing nothing but black.
        let rootLayer = CALayer()
        self.layer = rootLayer
        self.wantsLayer = true
        rootLayer.backgroundColor = currentTheme().day.panel.cgColor
        rootLayer.masksToBounds = true
        rootLayer.frame = bounds

        // Every hand starts at rest; primeNow() places the time.
        tracks = Array(repeating: Track(start: Self.REST), count: 48)

        panelLayer = CALayer()
        panelLayer.bounds = NSRect(x: 0, y: 0, width: Self.PANEL_W, height: Self.PANEL_H)
        panelLayer.position = NSPoint(x: bounds.midX, y: bounds.midY)
        panelLayer.anchorPoint = NSPoint(x: 0.5, y: 0.5)
        panelLayer.backgroundColor = NSColor.clear.cgColor
        rootLayer.addSublayer(panelLayer)

        // 24 dials, column-major-by-half-digit:
        //   index N → col = N/3, row = N%3
        for i in 0..<24 {
            let col = i / 3
            let row = i % 3
            let x = Self.PANEL_PAD + CGFloat(col) * (Self.DIAL_DIAM + Self.GAP)
            // CALayer y is bottom-up; row 0 should be at the top.
            let y = Self.PANEL_H - Self.PANEL_PAD - Self.DIAL_DIAM - CGFloat(row) * (Self.DIAL_DIAM + Self.GAP)

            let container = CALayer()
            container.frame = NSRect(x: x, y: y, width: Self.DIAL_DIAM, height: Self.DIAL_DIAM)
            container.masksToBounds = false
            panelLayer.addSublayer(container)
            dialContainerLayers.append(container)

            let backdrop = CALayer()
            backdrop.frame = container.bounds
            backdrop.contentsScale = 2.0
            container.addSublayer(backdrop)
            dialBackdropLayers.append(backdrop)

            let cx = Self.DIAL_DIAM / 2
            let cy = Self.DIAL_DIAM / 2

            let hour = makeHandLayer(length: Self.HOUR_LEN, color: currentTheme().day.hand)
            hour.position = NSPoint(x: cx, y: cy)
            let parkedRad = Self.layerRadians(Self.REST)
            hour.transform = CATransform3DMakeRotation(parkedRad, 0, 0, 1)
            container.addSublayer(hour)
            hourHandLayers.append(hour)

            let minH = makeHandLayer(length: Self.MIN_LEN, color: currentTheme().day.hand)
            minH.position = NSPoint(x: cx, y: cy)
            minH.transform = CATransform3DMakeRotation(parkedRad, 0, 0, 1)
            container.addSublayer(minH)
            minHandLayers.append(minH)

            let hub = CALayer()
            hub.bounds = NSRect(x: 0, y: 0, width: Self.HUB_DIAM, height: Self.HUB_DIAM)
            hub.cornerRadius = Self.HUB_DIAM / 2
            hub.position = NSPoint(x: cx, y: cy)
            hub.backgroundColor = currentTheme().day.hand.cgColor
            container.addSublayer(hub)
            hubLayers.append(hub)
        }
    }

    /// Hand layer: bounds = (length × HAND_W), anchorPoint = (0, 0.5).
    /// `position` equals the dial centre, so the rectangle starts AT the
    /// pivot and extends East before any rotation.
    private func makeHandLayer(length: CGFloat, color: NSColor) -> CALayer {
        let l = CALayer()
        l.bounds = NSRect(x: 0, y: 0, width: length, height: Self.HAND_W)
        l.anchorPoint = NSPoint(x: 0, y: 0.5)
        l.backgroundColor = color.cgColor
        return l
    }

    // MARK: - Dial backdrop (recess + sun shadow), generated as a CGImage
    fileprivate struct ShadowSpec: Equatable {
        let x: CGFloat
        let y: CGFloat
        let blur: CGFloat
        let alpha: CGFloat
    }

    /// `scale` is pixels per panel point, so the dial edge stays sharp on
    /// a big screen (the panel is scaled up to fill it).
    private func makeDialBackdrop(floor: NSColor, shadow: ShadowSpec, scale: CGFloat) -> CGImage {
        let size  = NSSize(width: Self.DIAL_DIAM, height: Self.DIAL_DIAM)
        let pxW = Int(size.width  * scale)
        let pxH = Int(size.height * scale)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil,
                            width: pxW, height: pxH,
                            bitsPerComponent: 8,
                            bytesPerRow: pxW * 4,
                            space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: scale, y: scale)

        let rect   = NSRect(origin: .zero, size: size)
        let circle = CGPath(ellipseIn: rect, transform: nil)

        // Floor fill clipped to the dial circle
        ctx.saveGState()
        ctx.addPath(circle)
        ctx.clip()
        ctx.setFillColor(floor.cgColor)
        ctx.fill(rect)
        ctx.restoreGState()

        // Inset shadow trick: clip to the circle and draw an INVERTED path
        // (donut shape) with a CG drop-shadow. The shadow falls inside the
        // circle's interior.
        ctx.saveGState()
        ctx.addPath(circle)
        ctx.clip()
        // CG bitmap y is bottom-up; our shadow.y is "down on screen", so
        // negate y for CG. Shadow offset and blur ignore the CTM (they are
        // in pixels), so scale them by hand to match clock.html.
        let shColor = NSColor.black.withAlphaComponent(shadow.alpha).cgColor
        ctx.setShadow(offset: CGSize(width: shadow.x * scale, height: -shadow.y * scale),
                      blur:   shadow.blur * scale,
                      color:  shColor)
        let inv = CGMutablePath()
        inv.addEllipse(in: rect)
        let halo = rect.insetBy(dx: -rect.width, dy: -rect.height)
        inv.addRect(halo)
        ctx.addPath(inv)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()

        return ctx.makeImage()!
    }

    private func sunShadow(hour24: Double) -> ShadowSpec {
        let isDay = (hour24 >= 6 && hour24 < 18)
        let t: Double
        if isDay {
            t = (hour24 - 6) / 12
        } else {
            let nightHour = (hour24 - 18 + 24).truncatingRemainder(dividingBy: 24)
            t = nightHour / 12
        }
        let horizontalRatio = 1 - 2 * t
        let x: CGFloat = CGFloat(horizontalRatio) * 4.5
        let alpha: CGFloat = isDay ? 0.24 : 0.18
        return ShadowSpec(x: x, y: 5, blur: 7, alpha: alpha)
    }

    // MARK: - Theme application
    private func currentTheme() -> Theme {
        return Self.THEMES[themeId] ?? Self.THEMES["studio"]!
    }

    private func currentPalette(hour24: Double) -> Palette {
        let isDay = (hour24 >= 6 && hour24 < 20)
        return isDay ? currentTheme().day : currentTheme().night
    }

    private func applyVisualState(hour24: Double) {
        let palette = currentPalette(hour24: hour24)
        let shadow  = sunShadow(hour24: hour24)
        let pkey = themeId + "|" + (hour24 >= 6 && hour24 < 20 ? "day" : "night")
        // Pixels per panel point, rounded up to a half step so small layout
        // changes don't redraw the backdrops.
        let pixelScale = max(1, (panelScale * (window?.backingScaleFactor ?? 2) * 2).rounded(.up) / 2)
        let skey = String(format: "%.2f,%.2f,%.2f,%.2f@%.1f", shadow.x, shadow.y, shadow.blur, shadow.alpha, pixelScale)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if pkey != lastPaletteKey || skey != lastShadowKey {
            let img = makeDialBackdrop(floor: palette.floor, shadow: shadow, scale: pixelScale)
            for backdrop in dialBackdropLayers {
                backdrop.contentsScale = pixelScale
                backdrop.contents = img
            }
        }
        if pkey != lastPaletteKey {
            for h in hourHandLayers { h.backgroundColor = palette.hand.cgColor }
            for h in minHandLayers  { h.backgroundColor = palette.hand.cgColor }
            for h in hubLayers      { h.backgroundColor = palette.hand.cgColor }
            layer?.backgroundColor = palette.panel.cgColor
        }

        CATransaction.commit()

        lastPaletteKey = pkey
        lastShadowKey  = skey
    }

    // MARK: - Motion engine
    //
    // The same engine as clock.html, in Swift. Angles are clock degrees:
    // 0 = 12 o'clock, 90 = 3, 180 = 6, 270 = 9, growing clockwise. Every
    // hand keeps a running (unwrapped) angle, so it can turn several times
    // in one move.
    //
    // A move is written down as a Track per hand: a start angle plus a
    // chain of timed turns. Core Animation plays each track as one keyframe
    // animation. Where a hand is "right now" always comes from the track
    // and the clock, never from the layer (reading a layer mid-flight gives
    // back the angle modulo a full turn, which throws the hand off course).
    // A new move replaces every track, starting from where the old tracks
    // say the hands are, so nothing is left over from the previous minute.

    fileprivate struct Turn {
        let t0: Double, t1: Double, a0: Double, a1: Double
        var out = false                 // ease out only (see moveTo)
    }

    fileprivate struct Track {
        var start: Double
        var turns: [Turn] = []

        var end: Double { return turns.last?.a1 ?? start }
        var endsAt: Double { return turns.last?.t1 ?? 0 }

        func angle(at t: Double) -> Double {
            var a = start
            for turn in turns {
                if t <= turn.t0 { return a }
                if t < turn.t1 {
                    let p = (t - turn.t0) / (turn.t1 - turn.t0)
                    return turn.a0 + (turn.a1 - turn.a0) * (turn.out ? 1 - (1 - p) * (1 - p) : SamayView.ease(p))
                }
                a = turn.a1
            }
            return a
        }
    }

    /// Small helper to write a track: wait, turn, wait, turn ...
    fileprivate struct Route {
        var angle: Double
        var t: Double = 0
        var track: Track

        init(from angle: Double) {
            self.angle = angle
            self.track = Track(start: angle)
        }
        mutating func wait(_ s: Double) { t += s }
        mutating func turn(by delta: Double, over s: Double) {
            if delta != 0 {
                track.turns.append(Turn(t0: t, t1: t + s, a0: angle, a1: angle + delta))
                angle += delta
            }
            t += s
        }
    }

    // One easing for every turn, a symmetric ease-in-out. clock.html uses
    // the same control points.
    private static let EASE: (Double, Double, Double, Double) = (0.6, 0.0, 0.4, 1.0)
    private static let easeFunction = CAMediaTimingFunction(
        controlPoints: Float(EASE.0), Float(EASE.1), Float(EASE.2), Float(EASE.3))
    /// 1 - (1 - p)², exactly, as a cubic Bézier: the coast of moveTo.
    private static let easeOutFunction = CAMediaTimingFunction(controlPoints: 1.0 / 3, 2.0 / 3, 2.0 / 3, 1)

    fileprivate static func ease(_ p: Double) -> Double {
        if p <= 0 { return 0 }
        if p >= 1 { return 1 }
        let (x1, y1, x2, y2) = EASE
        let cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx
        let cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by
        var u = p                                  // solve x(u) = p
        for _ in 0..<8 {
            let x = ((ax * u + bx) * u + cx) * u - p
            let dx = (3 * ax * u + 2 * bx) * u + cx
            if abs(x) < 1e-6 || abs(dx) < 1e-6 { break }
            u -= x / dx
        }
        u = min(1, max(0, u))
        return ((ay * u + by) * u + cy) * u
    }

    private static func wrap360(_ a: Double) -> Double {
        let r = a.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }
    /// Clockwise turn from a to b, in [0, 360).
    private static func forward(_ a: Double, _ b: Double) -> Double { return wrap360(b - a) }
    /// Anticlockwise turn from a to b, in (-360, 0].
    private static func backward(_ a: Double, _ b: Double) -> Double {
        let f = forward(a, b)
        return f == 0 ? 0 : f - 360
    }
    /// Shortest turn from a to b. A half turn goes the way `tie` says.
    private static func nearest(_ a: Double, _ b: Double, tie: Double = 1) -> Double {
        let f = forward(a, b)
        if f == 180 { return 180 * tie }
        return f < 180 ? f : f - 360
    }

    /// Which hand takes which of a dial's two target angles: the pairing
    /// that moves the hands least. Lines look the same either way round.
    private static func pairUp(_ from: (Double, Double), _ to: (Double, Double)) -> (Double, Double) {
        func cost(_ a: Double, _ b: Double) -> Double { return abs(nearest(a, b)) }
        let straight = cost(from.0, to.0) + cost(from.1, to.1)
        let crossed  = cost(from.0, to.1) + cost(from.1, to.0)
        return crossed < straight ? (to.1, to.0) : to
    }

    // Choreography timings, in seconds. Same numbers as clock.html.
    //   Waves: every column gathers into one shared pose (a diagonal line
    //          through each dial), spins it a full turn, then opens into the
    //          time. Columns start one after another: a ripple left to right.
    //   Lazy:  only dials whose digit changed move, the short way round.
    //   Fun:   every hand makes an extra full turn on the way. The two hands
    //          of a dial go opposite ways and neighbouring dials mirror each
    //          other, like gears. Starts in the middle.
    private enum Waves { static let stagger = 0.45, gather = 5.0, hold = 0.4, spin = 5.0, settle = 6.0 }
    private enum Lazy  { static let stagger = 0.40, move = 13.0 }
    private enum Fun   { static let stagger = 0.22, rowStep = 0.06, move = 15.0, extraTurns = 1.0 }
    private static let WAVE_POSE: (Double, Double) = (45, 225)

    private static func modeLength(_ mode: String) -> Double {
        switch mode {
        case "lazy": return 7 * Lazy.stagger + Lazy.move
        case "fun":  return 3.5 * Fun.stagger + 2 * Fun.rowStep + Fun.move
        default:     return 7 * Waves.stagger + Waves.gather + 2 * Waves.hold + Waves.spin + Waves.settle
        }
    }

    private static func planDial(mode: String, index i: Int,
                                 from: (Double, Double), target: (Double, Double)) -> [Route] {
        let col = Double(i / 3), row = Double(i % 3)
        let goal = pairUp(from, target)
        var routes = [Route(from: from.0), Route(from: from.1)]
        let goals = [goal.0, goal.1]
        let tie: [Double] = [1, -1]

        switch mode {
        case "lazy":
            if nearest(from.0, goal.0) == 0 && nearest(from.1, goal.1) == 0 { return routes }
            for k in 0..<2 {
                routes[k].wait(col * Lazy.stagger)
                routes[k].turn(by: nearest(routes[k].angle, goals[k], tie: tie[k]), over: Lazy.move)
            }

        case "fun":
            let delay = abs(col - 3.5) * Fun.stagger + row * Fun.rowStep
            let spin: Double = (Int(col + row) % 2 == 0) ? 1 : -1
            for k in 0..<2 {
                let dir = k == 0 ? spin : -spin
                let base = dir > 0 ? forward(routes[k].angle, goals[k]) : backward(routes[k].angle, goals[k])
                routes[k].wait(delay)
                routes[k].turn(by: base + dir * 360 * Fun.extraTurns, over: Fun.move)
            }

        default: // waves
            let line = pairUp(from, WAVE_POSE)
            let lineGoals = [line.0, line.1]
            for k in 0..<2 {
                routes[k].wait(col * Waves.stagger)
                routes[k].turn(by: nearest(routes[k].angle, lineGoals[k], tie: tie[k]), over: Waves.gather)
                routes[k].wait(Waves.hold)
                routes[k].turn(by: 360, over: Waves.spin)
                routes[k].wait(Waves.hold)
            }
            let settle = pairUp((routes[0].angle, routes[1].angle), target)
            let settleGoals = [settle.0, settle.1]
            for k in 0..<2 {
                routes[k].turn(by: nearest(routes[k].angle, settleGoals[k], tie: tie[k]), over: Waves.settle)
            }
        }
        return routes
    }

    // MARK: - Driving the layers

    private func handLayer(_ h: Int) -> CALayer {
        return h % 2 == 0 ? hourHandLayers[h / 2] : minHandLayers[h / 2]
    }

    /// Clock degrees → CALayer rotation. The hand layer points to 3 o'clock
    /// at rest, and CALayer turns anticlockwise for positive angles.
    private static func layerRadians(_ clockDeg: Double) -> Double {
        return (90 - clockDeg) * Double.pi / 180
    }

    /// A new move can start while the hands are still turning (a new mode
    /// or time format from the options sheet). Stopping them dead would
    /// look like a stutter, so every turning hand first coasts on at its
    /// current speed and slows to a stop over this long; the new plan
    /// starts from there. Same as clock.html.
    private static let COAST = 0.6

    /// Move every hand to `digits` with the given choreography, starting
    /// from wherever the current tracks put the hands right now.
    @discardableResult
    private func moveTo(digits: String, mode: String) -> Double {
        let now = CACurrentMediaTime()
        let pose = Self.poseFor(digits)
        let at = tracks.map { $0.angle(at: now) }
        let speed = tracks.map { ($0.angle(at: now + 0.001) - $0.angle(at: now - 0.001)) / 0.002 }  // deg per s
        let coast = speed.contains { abs($0) > 0.1 } ? Self.COAST : 0
        let t0 = now + coast
        let end = (0..<tracks.count).map { at[$0] + speed[$0] * coast / 2 }
        for i in 0..<24 {
            // Where each hand will be when the move starts, wrapped so numbers stay small.
            let from = (Self.wrap360(end[2 * i]), Self.wrap360(end[2 * i + 1]))
            let routes = Self.planDial(mode: mode, index: i, from: from, target: pose[i])
            for k in 0..<2 {
                let h = 2 * i + k
                let shift = end[h] - (k == 0 ? from.0 : from.1)      // keep the angle continuous
                var track = Track(start: at[h])
                if end[h] != at[h] {
                    track.turns.append(Turn(t0: now, t1: t0, a0: at[h], a1: end[h], out: true))
                }
                track.turns += routes[k].track.turns.map {
                    Turn(t0: $0.t0 + t0, t1: $0.t1 + t0, a0: $0.a0 + shift, a1: $0.a1 + shift)
                }
                tracks[h] = track
            }
        }
        play(from: now)
        return now
    }

    /// Show `digits` at once, no motion.
    func placeAt(digits: String) {
        let pose = Self.poseFor(digits)
        for i in 0..<24 {
            tracks[2 * i]     = Track(start: pose[i].0)
            tracks[2 * i + 1] = Track(start: pose[i].1)
        }
        play(from: CACurrentMediaTime())
    }

    /// Hand every track to Core Animation as one keyframe animation.
    private func play(from now: Double) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for h in 0..<tracks.count {
            let layer = handLayer(h)
            let track = tracks[h]
            layer.removeAnimation(forKey: "turn")
            // The model value is where the hand ends up.
            layer.transform = CATransform3DMakeRotation(CGFloat(Self.layerRadians(track.end)), 0, 0, 1)
            guard !track.turns.isEmpty, track.endsAt > now else { continue }

            let span = track.endsAt - now
            var times: [Double] = [0]
            var values: [Double] = [track.angle(at: now)]
            var curves: [CAMediaTimingFunction] = []
            for turn in track.turns where turn.t1 > now {
                let t0 = max(turn.t0, now)
                if t0 - now > times.last! * span + 1e-6 {          // a pause first
                    times.append((t0 - now) / span)
                    values.append(track.angle(at: t0))
                    curves.append(CAMediaTimingFunction(name: .linear))
                }
                times.append((turn.t1 - now) / span)
                values.append(turn.a1)
                curves.append(turn.out ? Self.easeOutFunction : Self.easeFunction)
            }
            let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            anim.values = values.map { NSNumber(value: Self.layerRadians($0)) }
            anim.keyTimes = times.map { NSNumber(value: min(1, max(0, $0))) }
            anim.timingFunctions = curves
            anim.calculationMode = .linear
            anim.beginTime = layer.convertTime(now, from: nil)
            anim.duration = span
            anim.isRemovedOnCompletion = true
            layer.add(anim, forKey: "turn")
        }
        CATransaction.commit()
    }

    private static func poseFor(_ digits: String) -> [(Double, Double)] {
        let chars = Array(digits)
        var pose: [(Double, Double)] = []
        for i in 0..<24 {
            let col = i / 3, row = i % 3
            let d = (col / 2 < chars.count) ? (Int(String(chars[col / 2])) ?? 0) : 0
            pose.append(GLYPHS[d][row][col % 2])
        }
        return pose
    }

    // MARK: - Time loop
    private func currentTimeStr() -> String {
        let cal = Calendar.current
        let d = Date()
        var hh = cal.component(.hour, from: d)
        let mm = cal.component(.minute, from: d)
        if !clockFormat24h {
            hh = hh % 12
            if hh == 0 { hh = 12 }
        }
        return String(format: "%02d%02d", hh, mm)
    }

    private func currentHour24() -> Double {
        let cal = Calendar.current
        let d = Date()
        let h = cal.component(.hour,   from: d)
        let m = cal.component(.minute, from: d)
        return Double(h) + Double(m) / 60.0
    }

    private func primeNow() {
        lastTime = currentTimeStr()
        lastMotion = motion
        placeAt(digits: lastTime)
        applyVisualState(hour24: currentHour24())
    }

    private func tick() {
        let t = currentTimeStr()
        if t != lastTime || motion != lastMotion {
            lastTime = t
            lastMotion = motion
            moveTo(digits: t, mode: motion)
        }
        applyVisualState(hour24: currentHour24())
    }

    /// Draw a fixed time in a given theme, for the offscreen snapshot script
    /// (mac/scripts/snapshot/main.swift). Not used by the screensaver itself.
    func snapshotPose(digits: String, theme: String, hour24: Double) {
        if Self.THEMES[theme] != nil { themeId = theme }
        repositionPanel()
        placeAt(digits: digits)
        lastPaletteKey = ""; lastShadowKey = ""
        applyVisualState(hour24: hour24)
    }

    /// Show `from` (or keep the hands where they are, if it is empty), then
    /// start the move to `to` exactly as the screensaver does each minute.
    /// Returns the move's start time (media time), so the snapshot script
    /// can draw any moment of it. Not used by the screensaver.
    func snapshotMove(from: String, to: String, mode: String, theme: String, hour24: Double) -> Double {
        if !from.isEmpty { snapshotPose(digits: from, theme: theme, hour24: hour24) }
        return moveTo(digits: to, mode: mode)
    }

    // MARK: - ScreenSaverView hooks
    public override func startAnimation() {
        super.startAnimation()
        repositionPanel()
        primeNow()
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.tick() }
        }
        if let t = tickTimer { RunLoop.main.add(t, forMode: .common) }
    }

    public override func stopAnimation() {
        super.stopAnimation()
        halt()
    }

    /// Stop all work: the clock timer and any turn still playing.
    private func halt() {
        tickTimer?.invalidate()
        tickTimer = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for h in 0..<min(tracks.count, hourHandLayers.count * 2) { handLayer(h).removeAnimation(forKey: "turn") }
        CATransaction.commit()
    }

    public override func animateOneFrame() {
        // Core Animation plays the frames.
    }

    public override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        repositionPanel()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        repositionPanel()
        // Re-render the dial backdrops at the new size
        lastPaletteKey = ""; lastShadowKey = ""
        applyVisualState(hour24: currentHour24())
    }

    public override func layout() {
        super.layout()
        repositionPanel()
    }

    public override func draw(_ rect: NSRect) {
        currentPalette(hour24: currentHour24()).panel.setFill()
        rect.fill()
    }

    private func repositionPanel() {
        guard let panelLayer = panelLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.frame = bounds
        panelLayer.position = NSPoint(x: bounds.midX, y: bounds.midY)
        let margin = min(bounds.width, bounds.height) * 0.04
        let sx = (bounds.width  - margin * 2) / Self.PANEL_W
        let sy = (bounds.height - margin * 2) / Self.PANEL_H
        let s = max(0.1, min(sx, sy))    // clamp away from zero in case bounds is unset
        panelScale = s
        panelLayer.transform = CATransform3DMakeScale(s, s, 1)
        CATransaction.commit()
    }

    // MARK: - Configure sheet
    public override var hasConfigureSheet: Bool { return true }

    private var themePopup: NSPopUpButton?
    private var motionSeg: NSSegmentedControl?
    private var formatSeg: NSSegmentedControl?

    public override var configureSheet: NSWindow? {
        // Important: we deliberately do NOT keep a `sheetWindow` reference
        // across calls. Earlier versions tracked the prior window and ran
        // a "close it before reopening" cleanup, but if the parent
        // wallpaper dialog had already been dismissed (the user pressed
        // Done at the OS level), the prior window is half-invalidated and
        // the cleanup closed something the host still referenced — so
        // the second Options click did nothing. Returning a fresh
        // standalone window each time, with no stored reference, lets
        // the host fully manage its lifecycle.
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = "Samay"
        panel.isReleasedWhenClosed = false

        let content = NSView(frame: panel.contentLayoutRect)
        content.autoresizingMask = [.width, .height]

        let themeLabel = NSTextField(labelWithString: "Theme")
        themeLabel.frame = NSRect(x: 24, y: 168, width: 80, height: 20)
        let popup = NSPopUpButton(frame: NSRect(x: 110, y: 164, width: 240, height: 26))
        for id in Self.THEME_ORDER {
            popup.addItem(withTitle: Self.THEME_NAMES[id] ?? id)
        }
        if let idx = Self.THEME_ORDER.firstIndex(of: themeId) { popup.selectItem(at: idx) }
        themePopup = popup

        let motionLabel = NSTextField(labelWithString: "Motion")
        motionLabel.frame = NSRect(x: 24, y: 124, width: 80, height: 20)
        let mSeg = NSSegmentedControl(labels: ["Waves", "Lazy", "Fun"],
                                      trackingMode: .selectOne,
                                      target: nil, action: nil)
        mSeg.frame = NSRect(x: 110, y: 120, width: 240, height: 26)
        switch motion {
        case "lazy": mSeg.selectedSegment = 1
        case "fun":  mSeg.selectedSegment = 2
        default:     mSeg.selectedSegment = 0
        }
        motionSeg = mSeg

        let formatLabel = NSTextField(labelWithString: "Format")
        formatLabel.frame = NSRect(x: 24, y: 80, width: 80, height: 20)
        let fSeg = NSSegmentedControl(labels: ["12-hour", "24-hour"],
                                      trackingMode: .selectOne,
                                      target: nil, action: nil)
        fSeg.frame = NSRect(x: 110, y: 76, width: 240, height: 26)
        fSeg.selectedSegment = clockFormat24h ? 1 : 0
        formatSeg = fSeg

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelSheet(_:)))
        cancel.frame = NSRect(x: 200, y: 16, width: 80, height: 32)
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"

        let ok = NSButton(title: "OK", target: self, action: #selector(saveSheet(_:)))
        ok.frame = NSRect(x: 286, y: 16, width: 80, height: 32)
        ok.bezelStyle = .rounded
        ok.keyEquivalent = "\r"

        for v in [themeLabel, popup, motionLabel, mSeg, formatLabel, fSeg, cancel, ok] {
            content.addSubview(v)
        }
        panel.contentView = content
        return panel
    }

    @objc private func saveSheet(_ sender: NSButton) {
        if let i = themePopup?.indexOfSelectedItem, i >= 0, i < Self.THEME_ORDER.count {
            themeId = Self.THEME_ORDER[i]
        }
        switch motionSeg?.selectedSegment ?? 0 {
        case 1: motion = "lazy"
        case 2: motion = "fun"
        default: motion = "waves"
        }
        clockFormat24h = (formatSeg?.selectedSegment == 1)
        savePrefs()
        // Reapply visuals immediately
        lastPaletteKey = ""; lastShadowKey = ""
        applyVisualState(hour24: currentHour24())
        dismissWindow(of: sender)
    }

    @objc private func cancelSheet(_ sender: NSButton) {
        dismissWindow(of: sender)
    }

    /// Dismiss the configure sheet by walking up from the clicked button to
    /// its window. Avoids relying on a self-stored window reference, which
    /// can go stale when the parent wallpaper dialog is dismissed at the
    /// OS level instead of through our buttons.
    private func dismissWindow(of sender: NSButton) {
        guard let win = sender.window else { return }
        if let parent = win.sheetParent {
            parent.endSheet(win)
        } else {
            win.close()
        }
        // Cached views were owned by the dismissed window; clear refs.
        themePopup = nil
        motionSeg  = nil
        formatSeg  = nil
    }

    // MARK: - Prefs
    private func loadPrefs() {
        let d = ScreenSaverDefaults(forModuleWithName: Self.defaultsName)
        if let m = d?.string(forKey: "motion"),
           ["waves", "lazy", "fun"].contains(m) { motion = m }
        if let t = d?.string(forKey: "theme"),
           Self.THEME_NAMES[t] != nil { themeId = t }
        if d?.object(forKey: "format24h") != nil {
            clockFormat24h = d?.bool(forKey: "format24h") ?? false
        }
    }

    private func savePrefs() {
        let d = ScreenSaverDefaults(forModuleWithName: Self.defaultsName)
        d?.set(motion,         forKey: "motion")
        d?.set(themeId,        forKey: "theme")
        d?.set(clockFormat24h, forKey: "format24h")
        d?.synchronize()
    }
}

