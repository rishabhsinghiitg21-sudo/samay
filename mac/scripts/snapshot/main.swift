// Draws the native screensaver view offscreen to a PNG, at a fixed time
// and theme, or at any moment of a move. Used to check the digits and the
// motion, and to make the System Settings thumbnails in mac/assets.
//
//   cd mac
//   mkdir -p build
//   swiftc -O -framework Cocoa -framework ScreenSaver -framework QuartzCore \
//          -o build/snapshot sources/SamayView.swift scripts/snapshot/main.swift
//   build/snapshot out.png 900 400 1008 studio 12 2
//                  file    w   h  digits theme hour scale
//   build/snapshot out.png 900 400 1259-1300 studio 12 2 waves 7.5
//                  ... a move from 12:59 to 13:00, drawn 7.5 s in

import Cocoa
import QuartzCore

let args = CommandLine.arguments
guard args.count >= 8 else {
    print("usage: snapshot out.png width height digits theme hour24 scale [mode seconds]")
    print("       with a mode, digits is FROM-TO, e.g. 1259-1300")
    exit(1)
}
let out = args[1]
let w = CGFloat(Double(args[2]) ?? 900), h = CGFloat(Double(args[3]) ?? 400)
let digits = args[4], theme = args[5]
let hour = Double(args[6]) ?? 12, scale = CGFloat(Double(args[7]) ?? 2)

guard let view = SamayView(frame: NSRect(x: 0, y: 0, width: w, height: h), isPreview: false),
      let root = view.layer else { print("could not make the view"); exit(1) }

if args.count >= 10 {
    // A moment of a move. Core Animation only keeps animations on layers
    // that live in a window, so host the view in an offscreen one. Start
    // the move, stop the layer clock at that moment, and copy what Core
    // Animation shows into the model layers (render(in:) draws model
    // values, not running animations).
    _ = NSApplication.shared
    let win = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: w, height: h),
                       styleMask: [.borderless], backing: .buffered, defer: false)
    win.contentView = view
    win.orderFrontRegardless()
    let parts = digits.split(separator: "-").map(String.init)
    guard parts.count == 2 else { print("digits must be FROM-TO with a mode"); exit(1) }
    let start = view.snapshotMove(from: parts[0], to: parts[1], mode: args[8], theme: theme, hour24: hour)
    CATransaction.flush()
    root.speed = 0
    root.timeOffset = start + (Double(args[9]) ?? 0)
    CATransaction.flush()
    func freeze(_ layer: CALayer) {
        if layer.animation(forKey: "turn") != nil, let p = layer.presentation() {
            layer.removeAllAnimations()
            layer.transform = p.transform
        }
        layer.sublayers?.forEach(freeze)
    }
    freeze(root)
} else {
    view.snapshotPose(digits: digits, theme: theme, hour24: hour)
}

let pxW = Int(w * scale), pxH = Int(h * scale)
let ctx = CGContext(data: nil, width: pxW, height: pxH, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.scaleBy(x: scale, y: scale)
root.render(in: ctx)
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
