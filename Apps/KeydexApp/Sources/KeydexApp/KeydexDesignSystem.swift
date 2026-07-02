import AppKit
import SwiftUI

enum KeydexGlassTone {
  static let sidebarSelectionFill = Color.primary.opacity(0.045)
  static let contentPanelFill = Color.primary.opacity(0.018)
  static let contentGlassTint = Color.white.opacity(0.035)
  static let controlGlassTint = Color.white.opacity(0.040)
  static let groupedRowsFill = Color.primary.opacity(0.010)
  static let railFloatingStroke = Color(nsColor: .separatorColor).opacity(0.18)
  static let railControlFill = Color.primary.opacity(0.045)
  static let panelStroke = Color(nsColor: .separatorColor).opacity(0.18)
  static let stateChipFillAlpha = 0.08
  static let stateChipStrokeAlpha = 0.24
  static let metadataChipFillAlpha = 0.07
  static let metadataChipStrokeAlpha = 0.22
  static let metadataChipFill = Color.primary.opacity(0.045)
  static let posterBadgeFill = Color.primary.opacity(0.045)
  static let posterBadgeStroke = Color(nsColor: .separatorColor).opacity(0.22)
  static let settingsActiveBackdropDimAlpha = 0.020
  static let settingsInactiveBackdropDimAlpha = 0.11
  static let settingsActivePanelWash = Color.white.opacity(0.006)
  static let settingsInactivePanelWash = Color.accentColor.opacity(0.040)
  static let artworkColorAlpha = 0.18
  static let posterSymbolAlpha = 0.50
  static let posterWashHighAlpha = 0.045
  static let posterHighlightAlpha = 0.055

  static func settingsBackdropDimAlpha(appearsActive: Bool) -> Double {
    appearsActive ? settingsActiveBackdropDimAlpha : settingsInactiveBackdropDimAlpha
  }

  static func settingsPanelWash(appearsActive: Bool) -> Color {
    appearsActive ? settingsActivePanelWash : settingsInactivePanelWash
  }

  static func settingsPanelStroke(appearsActive: Bool) -> Color {
    Color(nsColor: .separatorColor)
      .opacity(appearsActive ? 0.18 : 0.32)
  }

  static func settingsPanelStrokeWidth(appearsActive: Bool) -> CGFloat {
    appearsActive ? 1 : 1.25
  }
}

enum KeydexMotion {
  static let contentTransition = Animation.snappy(duration: 0.24, extraBounce: 0.04)
  static let controlHover = Animation.snappy(duration: 0.18, extraBounce: 0.08)
  static let railStateChange = Animation.snappy(duration: 0.24, extraBounce: 0.12)
}

enum KeydexRailLayout {
  static let horizontalMargin: CGFloat = 24
  static let footerLaneHeight: CGFloat = 90
  static let footerTopPadding: CGFloat = 12
  static let footerBottomPadding: CGFloat = 16
  static let footerSeparatorAlpha = 0.08
  static let railHeight: CGFloat = 58
  static let maxWidth: CGFloat = 720
  static let cornerRadius: CGFloat = 29
  static let glassContainerSpacing: CGFloat = 12
}

enum KeydexCardArtworkLayout {
  static let posterSymbolSize: CGFloat = 50
  static let compactSymbolSize: CGFloat = 34
}

enum KeydexCardDetailLayout {
  static let artworkSize: CGFloat = 224
  static let contentHorizontalPadding: CGFloat = 24
  static let contentTopPadding: CGFloat = 18
  static let contentBottomPadding: CGFloat = 24
  static let sectionSpacing: CGFloat = 18
  static let headerSpacing: CGFloat = 24
  static let titleStackSpacing: CGFloat = 10
}

enum KeydexCardGridLayout {
  static let contentHorizontalPadding: CGFloat = 24
  static let contentTopPadding: CGFloat = 18
  static let minimumColumnWidth: CGFloat = 212
  static let maximumColumnWidth: CGFloat = 304
  static let posterHeight: CGFloat = 248
  static let pageToSectionSpacing: CGFloat = 16
  static let sectionToGridSpacing: CGFloat = 10
  static let columnSpacing: CGFloat = 18
  static let rowSpacing: CGFloat = 14
  static let posterToTextSpacing: CGFloat = 8
  static let textDeckSpacing: CGFloat = 2
  static let textHorizontalInset: CGFloat = 2
  static let cardMinimumHeight: CGFloat = 286
  static let contentBottomPadding: CGFloat = 24
}

enum KeydexSidebarLayout {
  static let contentHorizontalPadding: CGFloat = 12
  static let contentBottomPadding: CGFloat = 18
  static let searchTopPadding: CGFloat = 12
  static let sectionSpacing: CGFloat = 14
  static let titleSpacing: CGFloat = 6
  static let rowSpacing: CGFloat = 2
  static let rowHeight: CGFloat = 34
  static let rowHorizontalPadding: CGFloat = 10
  static let searchRowHeight: CGFloat = 36
  static let searchHorizontalPadding: CGFloat = 12
}

enum KeydexSettingsLayout {
  static let panelWidth: CGFloat = 720
  static let panelHeight: CGFloat = 520
  static let panelCornerRadius: CGFloat = 14
  static let groupedRowsCornerRadius: CGFloat = 10
  static let glassContainerSpacing: CGFloat = 18
}

private struct KeydexGlassButtonModifier: ViewModifier {
  let prominent: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        if prominent {
          content.buttonStyle(.glassProminent)
        } else {
          content.buttonStyle(.glass)
        }
      } else {
        fallback(content: content)
      }
    #else
      fallback(content: content)
    #endif
  }

  @ViewBuilder
  private func fallback(content: Content) -> some View {
    if prominent {
      content.buttonStyle(.borderedProminent)
    } else {
      content.buttonStyle(.bordered)
    }
  }
}

private struct KeydexContentPanelModifier: ViewModifier {
  let stroke: Color
  let selected: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        content
          .glassEffect(.regular.tint(KeydexGlassTone.contentGlassTint).interactive(), in: shape)
          .overlay {
            shape.stroke(stroke, lineWidth: selected ? 1.5 : 1)
          }
      } else {
        fallback(content: content, in: shape)
      }
    #else
      fallback(content: content, in: shape)
    #endif
  }

  @ViewBuilder
  private func fallback(content: Content, in shape: RoundedRectangle) -> some View {
    content
      .background(KeydexGlassTone.contentPanelFill, in: shape)
      .overlay {
        shape.stroke(stroke, lineWidth: selected ? 1.5 : 1)
      }
  }
}

private struct KeydexArtworkGlassModifier: ViewModifier {
  let tint: Color
  let stroke: Color

  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        content
          .foregroundStyle(.clear)
          .glassEffect(.regular.tint(tint).interactive(), in: shape)
          .overlay {
            shape.fill(tint)
          }
          .overlay {
            shape.stroke(stroke, lineWidth: 1)
          }
      } else {
        fallback(content: content, in: shape)
      }
    #else
      fallback(content: content, in: shape)
    #endif
  }

  @ViewBuilder
  private func fallback(content: Content, in shape: RoundedRectangle) -> some View {
    content
      .foregroundStyle(.clear)
      .background(.thinMaterial, in: shape)
      .overlay {
        shape.fill(tint)
      }
      .overlay {
        shape.stroke(stroke, lineWidth: 1)
      }
  }
}

private struct KeydexControlGlassPanelModifier: ViewModifier {
  let cornerRadius: CGFloat

  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        content
          .glassEffect(.regular.tint(KeydexGlassTone.controlGlassTint).interactive(), in: shape)
          .overlay {
            shape.stroke(KeydexGlassTone.panelStroke, lineWidth: 1)
          }
      } else {
        fallback(content: content, in: shape)
      }
    #else
      fallback(content: content, in: shape)
    #endif
  }

  @ViewBuilder
  private func fallback(content: Content, in shape: RoundedRectangle) -> some View {
    content
      .background(.ultraThinMaterial, in: shape)
      .overlay {
        shape.stroke(KeydexGlassTone.panelStroke, lineWidth: 1)
      }
  }
}

private struct KeydexSheetGlassPanelModifier: ViewModifier {
  @Environment(\.appearsActive) private var appearsActive
  var namespace: Namespace.ID?

  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(
      cornerRadius: KeydexSettingsLayout.panelCornerRadius,
      style: .continuous
    )

    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        let glassContent =
          content
          .glassEffect(
            .clear.tint(KeydexGlassTone.settingsPanelWash(appearsActive: appearsActive))
              .interactive(),
            in: shape
          )
          .glassEffectTransition(.materialize)
          .overlay {
            shape.fill(KeydexGlassTone.settingsPanelWash(appearsActive: appearsActive))
          }
          .overlay {
            shape.stroke(
              KeydexGlassTone.settingsPanelStroke(appearsActive: appearsActive),
              lineWidth: KeydexGlassTone.settingsPanelStrokeWidth(appearsActive: appearsActive)
            )
          }

        if let namespace {
          glassContent
            .glassEffectID("settings-sheet", in: namespace)
        } else {
          glassContent
        }
      } else {
        fallback(content: content, in: shape)
      }
    #else
      fallback(content: content, in: shape)
    #endif
  }

  @ViewBuilder
  private func fallback(content: Content, in shape: RoundedRectangle) -> some View {
    content
      .background(.ultraThinMaterial, in: shape)
      .overlay {
        shape.fill(KeydexGlassTone.settingsPanelWash(appearsActive: appearsActive))
      }
      .overlay {
        shape.stroke(
          KeydexGlassTone.settingsPanelStroke(appearsActive: appearsActive),
          lineWidth: KeydexGlassTone.settingsPanelStrokeWidth(appearsActive: appearsActive)
        )
      }
  }
}

private struct KeydexGroupedRowsSurfaceModifier: ViewModifier {
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(
      cornerRadius: KeydexSettingsLayout.groupedRowsCornerRadius,
      style: .continuous
    )

    content
      .background(KeydexGlassTone.groupedRowsFill, in: shape)
      .overlay {
        shape.stroke(KeydexGlassTone.panelStroke, lineWidth: 1)
      }
  }
}

private struct KeydexCapsuleGlassModifier: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = Capsule()

    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        content
          .glassEffect(.regular.interactive(), in: shape)
          .overlay {
            shape.stroke(KeydexGlassTone.panelStroke, lineWidth: 1)
          }
      } else {
        fallback(content: content, in: shape)
      }
    #else
      fallback(content: content, in: shape)
    #endif
  }

  @ViewBuilder
  private func fallback(content: Content, in shape: Capsule) -> some View {
    content
      .background(.thinMaterial, in: shape)
      .overlay {
        shape.stroke(KeydexGlassTone.panelStroke, lineWidth: 1)
      }
  }
}

private struct KeydexFloatingGlassPanelModifier: ViewModifier {
  let stroke: Color

  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: KeydexRailLayout.cornerRadius, style: .continuous)

    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        content
          .glassEffect(.clear.interactive(), in: shape)
          .glassEffectTransition(.materialize)
          .overlay {
            shape.stroke(stroke, lineWidth: 1)
          }
      } else {
        fallback(content: content, in: shape)
      }
    #else
      fallback(content: content, in: shape)
    #endif
  }

  @ViewBuilder
  private func fallback(content: Content, in shape: RoundedRectangle) -> some View {
    content
      .background(.ultraThinMaterial, in: shape)
      .overlay {
        shape.stroke(stroke, lineWidth: 1)
      }
  }
}

private struct KeydexSidebarMaterialView: NSViewRepresentable {
  func makeNSView(context _: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    configure(view)
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
    configure(nsView)
  }

  private func configure(_ view: NSVisualEffectView) {
    view.material = .sidebar
    view.blendingMode = .withinWindow
    view.state = .active
    view.isEmphasized = false
  }
}

private struct KeydexSidebarGlassModifier: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        ZStack(alignment: .topLeading) {
          content
        }
        .background {
          KeydexSidebarMaterialView()
        }
        .backgroundExtensionEffect()
        .overlay(alignment: .trailing) {
          sidebarDivider
        }
      } else {
        fallback(content: content)
      }
    #else
      fallback(content: content)
    #endif
  }

  @ViewBuilder
  private func fallback(content: Content) -> some View {
    ZStack(alignment: .topLeading) {
      content
    }
    .background {
      KeydexSidebarMaterialView()
    }
    .overlay(alignment: .trailing) {
      sidebarDivider
    }
  }

  private var sidebarDivider: some View {
    Rectangle()
      .fill(.separator.opacity(0.22))
      .frame(width: 1)
  }
}

private struct KeydexSidebarSearchRowModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, KeydexSidebarLayout.searchHorizontalPadding)
      .frame(height: KeydexSidebarLayout.searchRowHeight)
      .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

extension View {
  func keydexGlassButton(prominent: Bool = false) -> some View {
    modifier(KeydexGlassButtonModifier(prominent: prominent))
  }

  func keydexContentPanel(stroke: Color, selected: Bool) -> some View {
    modifier(
      KeydexContentPanelModifier(
        stroke: stroke,
        selected: selected
      )
    )
  }

  func keydexArtworkGlass(tint: Color, stroke: Color) -> some View {
    modifier(KeydexArtworkGlassModifier(tint: tint, stroke: stroke))
  }

  func keydexControlGlassPanel(cornerRadius: CGFloat) -> some View {
    modifier(KeydexControlGlassPanelModifier(cornerRadius: cornerRadius))
  }

  func keydexSheetGlassPanel() -> some View {
    modifier(KeydexSheetGlassPanelModifier(namespace: nil))
  }

  func keydexSheetGlassPanel(namespace: Namespace.ID) -> some View {
    modifier(KeydexSheetGlassPanelModifier(namespace: namespace))
  }

  func keydexCapsuleGlass() -> some View {
    modifier(KeydexCapsuleGlassModifier())
  }

  func keydexGroupedRowsSurface() -> some View {
    modifier(KeydexGroupedRowsSurfaceModifier())
  }

  func keydexFloatingGlassPanel(stroke: Color) -> some View {
    modifier(KeydexFloatingGlassPanelModifier(stroke: stroke))
  }

  func keydexSidebarGlass() -> some View {
    modifier(KeydexSidebarGlassModifier())
  }

  func keydexSidebarSearchRow() -> some View {
    modifier(KeydexSidebarSearchRowModifier())
  }
}
