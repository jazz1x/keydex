import AppKit
import SwiftUI

enum KeydexAppIcon {
  @MainActor
  static func installApplicationIcon() {
    NSApplication.shared.applicationIconImage = requiredImage(named: "KeydexAppIcon")
  }

  @MainActor
  static func trayTemplateImage() -> NSImage {
    let image = requiredImage(named: "KeydexTrayTemplate")
    image.isTemplate = true
    image.size = NSSize(width: 18, height: 18)
    return image
  }

  private static func requiredImage(named name: String) -> NSImage {
    guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
      let image = NSImage(contentsOf: url)
    else {
      preconditionFailure("Missing bundled Keydex image resource: \(name).png")
    }

    return image
  }
}

struct WindowPresetApplier: NSViewRepresentable {
  let size: CGSize?

  func makeNSView(context _: Context) -> NSView {
    let view = WindowPresetView()
    view.size = size
    return view
  }

  func updateNSView(_ nsView: NSView, context _: Context) {
    guard let view = nsView as? WindowPresetView else {
      return
    }

    view.size = size
    view.applyPreset()
  }
}

private final class WindowPresetView: NSView {
  var size: CGSize?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    applyPreset()
  }

  func applyPreset() {
    guard let size, let window else {
      return
    }

    let contentRect = NSRect(origin: .zero, size: size)
    var frame = window.frameRect(forContentRect: contentRect)
    frame.origin = window.frame.origin
    window.setFrame(frame, display: true)
  }
}
