import AppKit
import KeydexCore
import SwiftUI
import UniformTypeIdentifiers

private struct EmptyStatePanel: View {
  let title: String
  let systemImage: String
  let description: String
  let secondaryText: String

  var body: some View {
    VStack(alignment: .center, spacing: 4) {
      Image(systemName: systemImage)
        .font(.system(size: 30))
        .foregroundStyle(.secondary)
      Text(title)
        .font(.headline)
      Text(description)
        .foregroundStyle(.secondary)
      Text(secondaryText)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .multilineTextAlignment(.center)
    .accessibilityIdentifier("keydex.inventory.empty-state")
    .accessibilityLabel("Empty credential inventory state")
    .accessibilityValue("\(title). \(description). \(secondaryText)")
  }
}

enum InventoryEmptyState: Equatable {
  case explicitEmpty
  case localInventory
  case filtered

  var title: String {
    switch self {
    case .explicitEmpty:
      "No credentials"
    case .localInventory:
      "No local credentials indexed yet"
    case .filtered:
      "No matching credentials"
    }
  }

  var systemImage: String {
    switch self {
    case .explicitEmpty:
      "tray"
    case .localInventory:
      "tray.and.arrow.down"
    case .filtered:
      "line.3.horizontal.decrease.circle"
    }
  }

  var description: String {
    switch self {
    case .explicitEmpty:
      "This dataset is intentionally empty."
    case .localInventory:
      "Add scan paths or Keychain references in Settings, then refresh inventory."
    case .filtered:
      "No rows match this scope or search."
    }
  }

  var secondaryText: String {
    switch self {
    case .explicitEmpty:
      "Use Local or Sample mode to populate credentials."
    case .localInventory:
      "Keydex stores references and metadata only; secret values stay out of inventory."
    case .filtered:
      "Clear search or choose another scope."
    }
  }
}

struct InventoryContentView: View {
  let rows: [CredentialRow]
  let title: String
  let searchText: String
  let displayMode: InventoryDisplayMode
  @Binding var selectedCredentialID: CredentialRow.ID?
  let emptyState: InventoryEmptyState
  let footerReserveHeight: CGFloat
  let artworkRootURL: URL
  let manageKeychainAction: () -> Void
  let manageTagsAction: () -> Void
  let importArtworkAction: (URL, CredentialRow) -> Void
  let resetArtworkAction: (CredentialRow) -> Void
  let artworkFailureAction: (Error) -> Void
  @State private var cardReturnAnchorID: CredentialRow.ID?

  var body: some View {
    ZStack {
      switch displayMode {
      case .list:
        VStack(spacing: 0) {
          if let activeSearchQuery {
            MusicSearchResultHeader(query: activeSearchQuery, resultCount: rows.count)
          }

          CredentialInventoryTable(rows: rows, selectedCredentialID: $selectedCredentialID)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
          Color.clear
            .frame(height: footerReserveHeight)
            .accessibilityHidden(true)
        }
      case .cards:
        if let selectedCardRow {
          CredentialMusicDetailView(
            row: selectedCardRow,
            footerReserveHeight: footerReserveHeight,
            artworkRootURL: artworkRootURL,
            manageKeychainAction: manageKeychainAction,
            manageTagsAction: manageTagsAction,
            importArtworkAction: importArtworkAction,
            resetArtworkAction: resetArtworkAction,
            artworkFailureAction: artworkFailureAction
          ) {
            withAnimation(KeydexMotion.contentTransition) {
              selectedCredentialID = nil
            }
          }
          .transition(.opacity.combined(with: .scale(scale: 0.985)))
        } else {
          CredentialCardGrid(
            rows: rows,
            title: title,
            searchText: searchText,
            footerReserveHeight: footerReserveHeight,
            artworkRootURL: artworkRootURL,
            restoreScrollAnchorID: cardReturnAnchorID,
            selectedCredentialID: $selectedCredentialID
          ) { rowID in
            cardReturnAnchorID = rowID
            withAnimation(KeydexMotion.contentTransition) {
              selectedCredentialID = rowID
            }
          }
          .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
      }

      if rows.isEmpty {
        EmptyStatePanel(
          title: emptyState.title,
          systemImage: emptyState.systemImage,
          description: emptyState.description,
          secondaryText: emptyState.secondaryText
        )
      }
    }
    .animation(KeydexMotion.contentTransition, value: displayMode)
    .animation(KeydexMotion.contentTransition, value: selectedCredentialID)
  }

  private var activeSearchQuery: String? {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private var selectedCardRow: CredentialRow? {
    selectedCredentialID.flatMap { selectedID in
      rows.first { $0.id == selectedID }
    }
  }
}

private struct MusicSearchResultHeader: View {
  let query: String
  let resultCount: Int

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text("Search")
        .font(.title2.weight(.bold))

      Text(query)
        .font(.title3.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)

      Spacer(minLength: 12)

      Text("\(resultCount) results")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 18)
    .padding(.top, 14)
    .padding(.bottom, 8)
    .accessibilityIdentifier("keydex.inventory.search-results-header")
    .accessibilityLabel("Search results for \(query), \(resultCount) results")
  }
}

private struct CredentialInventoryTable: View {
  let rows: [CredentialRow]
  @Binding var selectedCredentialID: CredentialRow.ID?

  var body: some View {
    Table(rows, selection: $selectedCredentialID) {
      TableColumn("Service") { row in
        Text(row.service)
          .font(.body.weight(.medium))
      }

      TableColumn("Account") { row in
        Text(row.account)
          .fontDesign(.monospaced)
      }

      TableColumn("State") { row in
        CredentialStateSummaryView(states: row.states)
      }

      TableColumn("Keychain") { row in
        Label(row.keychainStatusTitle, systemImage: row.keychainStatusSystemImage)
          .foregroundStyle(keychainTint(for: row))
      }

      TableColumn("Tags") { row in
        CredentialTagStrip(tags: row.tags, limit: 2, compact: true)
      }
      .width(min: 128, ideal: 152)

      TableColumn("Sources") { row in
        Text("\(row.locations.count)")
      }
      .width(min: 64, ideal: 74, max: 86)
    }
    .accessibilityIdentifier("keydex.inventory.table")
    .accessibilityLabel("Credential inventory table")
    .font(.body)
  }
}

private struct CredentialCardGrid: View {
  let rows: [CredentialRow]
  let title: String
  let searchText: String
  let footerReserveHeight: CGFloat
  let artworkRootURL: URL
  let restoreScrollAnchorID: CredentialRow.ID?
  @Binding var selectedCredentialID: CredentialRow.ID?
  let selectCredential: (CredentialRow.ID) -> Void
  @FocusState private var focusedCredentialID: CredentialRow.ID?

  private let columns = [
    GridItem(
      .adaptive(
        minimum: KeydexCardGridLayout.minimumColumnWidth,
        maximum: KeydexCardGridLayout.maximumColumnWidth
      ),
      spacing: KeydexCardGridLayout.columnSpacing,
      alignment: .top
    )
  ]

  var body: some View {
    ZStack {
      InventoryBackdropView()

      ScrollViewReader { scrollProxy in
        ScrollView {
          VStack(alignment: .leading, spacing: KeydexCardGridLayout.pageToSectionSpacing) {
            Text(title)
              .font(.largeTitle.weight(.bold))
              .lineLimit(1)

            VStack(alignment: .leading, spacing: KeydexCardGridLayout.sectionToGridSpacing) {
              MusicContentSectionHeader(title: sectionTitle)

              LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: KeydexCardGridLayout.rowSpacing
              ) {
                ForEach(rows) { row in
                  CredentialInventoryCard(
                    row: row,
                    artworkRootURL: artworkRootURL,
                    isSelected: selectedCredentialID == row.id,
                    isKeyboardFocused: focusedCredentialID == row.id
                  ) {
                    selectCredential(row.id)
                  }
                  .id(row.id)
                  .focused($focusedCredentialID, equals: row.id)
                  .focusEffectDisabled()
                }
              }
            }
          }
          .padding(.horizontal, KeydexCardGridLayout.contentHorizontalPadding)
          .padding(.top, KeydexCardGridLayout.contentTopPadding)
          .padding(.bottom, KeydexCardGridLayout.contentBottomPadding + footerReserveHeight)
        }
        .onAppear {
          if let restoreScrollAnchorID {
            scrollProxy.scrollTo(restoreScrollAnchorID, anchor: .center)
          }
        }
      }
    }
    .accessibilityIdentifier("keydex.inventory.cards")
    .accessibilityLabel("Credential inventory cards")
  }

  private var sectionTitle: String {
    activeSearchQuery == nil ? "Credential Library" : "Top Results"
  }

  private var activeSearchQuery: String? {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

private struct MusicContentSectionHeader: View {
  let title: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(title)
        .font(.title2.weight(.bold))

      Image(systemName: "chevron.right")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct CredentialInventoryCard: View {
  let row: CredentialRow
  let artworkRootURL: URL
  let isSelected: Bool
  let isKeyboardFocused: Bool
  let selectAction: () -> Void

  var body: some View {
    Button(action: selectAction) {
      VStack(alignment: .leading, spacing: KeydexCardGridLayout.posterToTextSpacing) {
        CredentialArtworkPanel(
          row: row,
          height: KeydexCardGridLayout.posterHeight,
          artworkRootURL: artworkRootURL,
          emphasis: artworkEmphasis
        )

        VStack(alignment: .leading, spacing: KeydexCardGridLayout.textDeckSpacing) {
          Text(row.service)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)

          Text(row.cardCaptionLine)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KeydexCardGridLayout.textHorizontalInset)
      }
      .frame(
        maxWidth: .infinity,
        minHeight: KeydexCardGridLayout.cardMinimumHeight,
        alignment: .topLeading
      )
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .accessibilityLabel(row.cardAccessibilityLabel)
  }

  private var artworkEmphasis: CredentialArtworkEmphasis {
    if isKeyboardFocused {
      return .keyboardFocus
    }

    if isSelected {
      return .selected
    }

    return .none
  }
}

private enum CredentialArtworkEmphasis {
  case none
  case selected
  case keyboardFocus
}

private struct CredentialArtworkPanel: View {
  let row: CredentialRow
  var height: CGFloat = 82
  let artworkRootURL: URL
  var emphasis: CredentialArtworkEmphasis = .none

  var body: some View {
    ZStack {
      panelShape
        .keydexArtworkGlass(tint: panelFill, stroke: panelStroke)
        .overlay {
          if let artworkOverride = row.artworkOverride {
            CredentialCustomArtwork(
              override: artworkOverride,
              fallbackPreset: preset,
              artworkRootURL: artworkRootURL,
              isPoster: isPoster
            )
            .clipShape(panelShape)
          } else {
            CredentialDefaultArtwork(preset: preset, isPoster: isPoster)
              .clipShape(panelShape)
          }
        }
        .overlay(alignment: .topTrailing) {
          Text("\(row.locations.count)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(KeydexGlassTone.posterBadgeFill, in: Capsule())
            .overlay {
              Capsule()
                .stroke(KeydexGlassTone.posterBadgeStroke, lineWidth: 1)
            }
            .padding(10)
        }
        .overlay(alignment: .bottomLeading) {
          if !isPoster {
            VStack(alignment: .leading, spacing: 4) {
              Text(row.keychainStatusTitle.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(accentColor)
                .lineLimit(1)

              Text("\(row.locations.count) source locations")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .padding(12)
          }
        }
    }
    .frame(height: height)
  }

  private var panelFill: Color {
    preset.primaryTint.opacity(KeydexGlassTone.artworkColorAlpha)
  }

  private var panelStroke: Color {
    switch emphasis {
    case .keyboardFocus:
      return Color.primary.opacity(isPoster ? 0.30 : 0.22)
    case .selected:
      return preset.primaryTint.opacity(isPoster ? 0.28 : 0.20)
    case .none:
      return preset.primaryTint.opacity(isPoster ? 0.18 : 0.12)
    }
  }

  private var panelRadius: CGFloat {
    isPoster ? 8 : 6
  }

  private var isPoster: Bool {
    height > 120
  }

  private var preset: CredentialArtworkPreset {
    row.artworkPreset
  }

  private var accentColor: Color {
    preset.primaryTint
  }

  private var panelShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: panelRadius, style: .continuous)
  }
}

private struct CredentialPosterWash: View {
  let preset: CredentialArtworkPreset
  let isPoster: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        Rectangle()
          .fill(preset.primaryTint.opacity(isPoster ? 0.26 : 0.18))
        Rectangle()
          .fill(preset.secondaryTint.opacity(isPoster ? 0.24 : 0.16))
      }

      HStack(spacing: 0) {
        Rectangle()
          .fill(preset.tertiaryTint.opacity(isPoster ? 0.22 : 0.15))
        Rectangle()
          .fill(preset.primaryTint.opacity(isPoster ? 0.16 : 0.11))
      }
    }
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.white.opacity(KeydexGlassTone.posterHighlightAlpha))
        .frame(height: isPoster ? 48 : 24)
    }
  }
}

private struct CredentialCustomArtwork: View {
  let override: CredentialArtworkOverride
  let fallbackPreset: CredentialArtworkPreset
  let artworkRootURL: URL
  let isPoster: Bool

  var body: some View {
    let imageURL = override.fileURL(rootURL: artworkRootURL)

    if let image = NSImage(contentsOf: imageURL) {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .accessibilityHidden(true)
    } else {
      ZStack {
        CredentialDefaultArtwork(preset: fallbackPreset, isPoster: isPoster)

        Label("Missing custom artwork", systemImage: "exclamationmark.triangle.fill")
          .font(.caption2.weight(.semibold))
          .labelStyle(.iconOnly)
          .foregroundStyle(.secondary)
          .padding(6)
          .background(Color.white.opacity(0.20), in: Capsule())
      }
      .accessibilityHidden(true)
    }
  }
}

private struct CredentialDefaultArtwork: View {
  let preset: CredentialArtworkPreset
  let isPoster: Bool

  var body: some View {
    ZStack {
      CredentialPosterWash(preset: preset, isPoster: isPoster)

      VStack(spacing: isPoster ? 12 : 6) {
        ZStack {
          Circle()
            .fill(Color.white.opacity(isPoster ? 0.20 : 0.16))
            .overlay {
              Circle()
                .stroke(Color.white.opacity(isPoster ? 0.34 : 0.24), lineWidth: 1)
            }
            .frame(width: isPoster ? 86 : 48, height: isPoster ? 86 : 48)

          Image(systemName: preset.symbolName)
            .font(
              .system(
                size: isPoster
                  ? KeydexCardArtworkLayout.posterSymbolSize
                  : KeydexCardArtworkLayout.compactSymbolSize,
                weight: .semibold
              )
            )
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.white.opacity(KeydexGlassTone.posterSymbolAlpha + 0.28))
            .accessibilityHidden(true)
        }

        if isPoster {
          Text(preset.monogram)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.14), in: Capsule())
        }
      }
    }
    .accessibilityHidden(true)
  }
}

private struct InventoryBackdropView: View {
  var body: some View {
    baseFill
  }

  private var baseFill: Color {
    Color(nsColor: .windowBackgroundColor)
  }
}

private struct CredentialStateSummaryView: View {
  let states: [CredentialState]

  var body: some View {
    HStack(spacing: 4) {
      ForEach(states, id: \.self) { state in
        CredentialStateChip(state: state)
      }
    }
  }
}

private struct CredentialStateChip: View {
  let state: CredentialState

  var body: some View {
    Label(canonicalStateLabel([state]), systemImage: stateSystemImage(for: state))
      .font(.caption.weight(.medium))
      .labelStyle(.titleAndIcon)
      .foregroundStyle(stateTint(for: state))
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(
        stateTint(for: state).opacity(KeydexGlassTone.stateChipFillAlpha),
        in: Capsule()
      )
      .overlay {
        Capsule()
          .stroke(stateTint(for: state).opacity(KeydexGlassTone.stateChipStrokeAlpha), lineWidth: 1)
      }
  }
}

private struct KeychainStatusBadge: View {
  let row: CredentialRow

  var body: some View {
    Label(row.keychainStatusTitle, systemImage: row.keychainStatusSystemImage)
      .font(.caption.weight(.medium))
      .foregroundStyle(keychainTint(for: row))
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        keychainTint(for: row).opacity(KeydexGlassTone.metadataChipFillAlpha),
        in: Capsule()
      )
      .overlay {
        Capsule()
          .stroke(
            keychainTint(for: row).opacity(KeydexGlassTone.metadataChipStrokeAlpha),
            lineWidth: 1
          )
      }
  }
}

private struct CredentialTagStrip: View {
  let tags: [CredentialTagRow]
  var limit = 4
  var compact = false

  private var visibleTags: [CredentialTagRow] {
    Array(tags.prefix(limit))
  }

  private var hiddenCount: Int {
    max(tags.count - visibleTags.count, 0)
  }

  var body: some View {
    HStack(spacing: compact ? 4 : 6) {
      if visibleTags.isEmpty {
        Text("No tags")
          .font(compact ? .caption2 : .caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(visibleTags) { tag in
          CredentialTagChip(tag: tag, compact: compact)
        }

        if hiddenCount > 0 {
          Text("+\(hiddenCount)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(KeydexGlassTone.metadataChipFill, in: Capsule())
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(tagAccessibilityLabel)
  }

  private var tagAccessibilityLabel: String {
    if tags.isEmpty {
      return "No tags"
    }

    return "Tags \(tags.map(\.name).joined(separator: ", "))"
  }
}

private struct CredentialTagChip: View {
  let tag: CredentialTagRow
  var compact = false

  var body: some View {
    HStack(spacing: compact ? 4 : 6) {
      Circle()
        .fill(tag.color.tint)
        .frame(width: compact ? 6 : 7, height: compact ? 6 : 7)
        .accessibilityHidden(true)

      Text(tag.name)
        .lineLimit(1)
    }
    .font(compact ? .caption2.weight(.medium) : .caption.weight(.medium))
    .foregroundStyle(.primary)
    .padding(.horizontal, compact ? 6 : 8)
    .padding(.vertical, compact ? 3 : 4)
    .background(KeydexGlassTone.metadataChipFill, in: Capsule())
    .overlay {
      Capsule()
        .stroke(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
    }
  }
}

private struct CredentialArtworkActionGroup: View {
  let row: CredentialRow
  let compact: Bool
  let importArtworkAction: (URL, CredentialRow) -> Void
  let resetArtworkAction: (CredentialRow) -> Void
  let artworkFailureAction: (Error) -> Void
  @State private var isImportingArtwork = false

  var body: some View {
    Group {
      if compact {
        VStack(alignment: .leading, spacing: 8) {
          artworkButtons
        }
      } else {
        HStack(spacing: 8) {
          artworkButtons
        }
      }
    }
    .fileImporter(isPresented: $isImportingArtwork, allowedContentTypes: [.image]) { result in
      switch result {
      case .success(let sourceURL):
        importArtworkAction(sourceURL, row)
      case .failure(let error):
        artworkFailureAction(error)
      }
    }
  }

  @ViewBuilder
  private var artworkButtons: some View {
    Button {
      isImportingArtwork = true
    } label: {
      Label("Choose Artwork", systemImage: "photo.on.rectangle.angled")
    }
    .keydexActionButton(compact: compact)
    .help("Import a custom card artwork image")
    .accessibilityIdentifier("keydex.artwork.choose")
    .accessibilityLabel("Choose custom artwork")

    if row.artworkOverride != nil {
      Button {
        resetArtworkAction(row)
      } label: {
        Label("Reset Artwork", systemImage: "arrow.counterclockwise")
      }
      .keydexActionButton(compact: compact)
      .help("Reset to the default artwork preset")
      .accessibilityIdentifier("keydex.artwork.reset")
      .accessibilityLabel("Reset custom artwork")
    }
  }
}

struct CredentialInspectorPanel: View {
  let row: CredentialRow
  let artworkRootURL: URL
  let manageKeychainAction: () -> Void
  let manageTagsAction: () -> Void
  let importArtworkAction: (URL, CredentialRow) -> Void
  let resetArtworkAction: (CredentialRow) -> Void
  let artworkFailureAction: (Error) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        CredentialArtworkPanel(row: row, artworkRootURL: artworkRootURL)
          .frame(height: 148)

        VStack(alignment: .leading, spacing: 6) {
          Text(row.service)
            .font(.largeTitle.weight(.bold))
            .lineLimit(1)

          Text(row.account)
            .font(.title3)
            .fontDesign(.monospaced)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        HStack(spacing: 10) {
          Button(action: manageKeychainAction) {
            Label("Manage Keychain", systemImage: "key.fill")
          }
          .keydexActionButton()
          .help("Open Keychain reference management")
          .accessibilityIdentifier("keydex.inspector.manage-keychain")
          .accessibilityLabel("Manage Keychain reference")

          KeychainStatusBadge(row: row)
        }

        CredentialArtworkActionGroup(
          row: row,
          compact: true,
          importArtworkAction: importArtworkAction,
          resetArtworkAction: resetArtworkAction,
          artworkFailureAction: artworkFailureAction
        )

        InspectorGlassSection(
          title: "States",
          systemImage: "checklist"
        ) {
          CredentialStateSummaryView(states: row.states)
        }

        InspectorGlassSection(
          title: "Tags",
          systemImage: "tag"
        ) {
          VStack(alignment: .leading, spacing: 10) {
            CredentialTagStrip(tags: row.tags, limit: 4)

            Button(action: manageTagsAction) {
              Label("Manage Tags", systemImage: "tag.fill")
            }
            .keydexActionButton()
            .help("Open tag management")
            .accessibilityIdentifier("keydex.inspector.manage-tags")
            .accessibilityLabel("Manage credential tags")
          }
        }

        InspectorGlassSection(
          title: "Keychain",
          systemImage: keychainCount(for: row.projection) > 0 ? "key.fill" : "key.slash"
        ) {
          Label(
            keychainSummary(for: row.projection),
            systemImage: keychainCount(for: row.projection) > 0 ? "key.fill" : "key.slash"
          )
          .foregroundStyle(keychainTint(for: row.projection))
          .font(.callout)
        }

        InspectorGlassSection(
          title: "Sources",
          systemImage: "list.bullet.rectangle"
        ) {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(row.projection.locations, id: \.self) { location in
              Text(locationLabel(location))
                .font(.callout)
                .textSelection(.enabled)
            }
          }
        }
      }
      .padding(18)
    }
  }
}

private struct CredentialMusicDetailView: View {
  let row: CredentialRow
  let footerReserveHeight: CGFloat
  let artworkRootURL: URL
  let manageKeychainAction: () -> Void
  let manageTagsAction: () -> Void
  let importArtworkAction: (URL, CredentialRow) -> Void
  let resetArtworkAction: (CredentialRow) -> Void
  let artworkFailureAction: (Error) -> Void
  let closeAction: () -> Void

  var body: some View {
    ZStack {
      InventoryBackdropView()

      ScrollView {
        VStack(alignment: .leading, spacing: KeydexCardDetailLayout.sectionSpacing) {
          Button(action: closeAction) {
            Label("Credential Library", systemImage: "chevron.left")
          }
          .keydexNavigationButton()
          .help("Return to credential library")
          .accessibilityIdentifier("keydex.card-detail.back")

          HStack(alignment: .bottom, spacing: KeydexCardDetailLayout.headerSpacing) {
            CredentialArtworkPanel(
              row: row,
              height: KeydexCardDetailLayout.artworkSize,
              artworkRootURL: artworkRootURL
            )
            .frame(width: KeydexCardDetailLayout.artworkSize)

            VStack(alignment: .leading, spacing: KeydexCardDetailLayout.titleStackSpacing) {
              Text("Credential")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

              Text(row.service)
                .font(.system(size: 38, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

              Text(row.account)
                .font(.title3)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
                .lineLimit(1)

              CredentialStateSummaryView(states: row.states)

              CredentialTagStrip(tags: row.tags, limit: 3)

              HStack(spacing: 10) {
                Button(action: manageKeychainAction) {
                  Label("Manage Keychain", systemImage: "key.fill")
                }
                .keydexActionButton()
                .help("Open Keychain reference management")
                .accessibilityIdentifier("keydex.card-detail.manage-keychain")
                .accessibilityLabel("Manage Keychain reference")

                Button(action: manageTagsAction) {
                  Label("Manage Tags", systemImage: "tag.fill")
                }
                .keydexActionButton()
                .help("Open tag management")
                .accessibilityIdentifier("keydex.card-detail.manage-tags")
                .accessibilityLabel("Manage credential tags")

                KeychainStatusBadge(row: row)
              }

              CredentialArtworkActionGroup(
                row: row,
                compact: false,
                importArtworkAction: importArtworkAction,
                resetArtworkAction: resetArtworkAction,
                artworkFailureAction: artworkFailureAction
              )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }

          VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
              Text("Sources")
                .font(.title2.weight(.bold))

              Spacer()

              Text("\(row.locations.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
              Divider()

              ForEach(Array(row.locations.enumerated()), id: \.offset) { index, location in
                MusicSourceTrackRow(index: index + 1, location: location)

                if index + 1 < row.locations.count {
                  Divider()
                    .padding(.leading, 44)
                }
              }

              Divider()
            }
          }
          .padding(.top, 4)
        }
        .padding(.horizontal, KeydexCardDetailLayout.contentHorizontalPadding)
        .padding(.top, KeydexCardDetailLayout.contentTopPadding)
        .padding(.bottom, KeydexCardDetailLayout.contentBottomPadding + footerReserveHeight)
      }
    }
    .accessibilityIdentifier("keydex.card-detail.page")
    .accessibilityLabel("Credential card detail")
  }
}

private struct MusicSourceTrackRow: View {
  let index: Int
  let location: CredentialLocation

  var body: some View {
    HStack(spacing: 12) {
      Text("\(index)")
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 20, alignment: .trailing)

      Image(systemName: locationSystemImage(location))
        .font(.body.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 20)

      VStack(alignment: .leading, spacing: 2) {
        Text(locationKindTitle(location))
          .font(.callout.weight(.medium))

        Text(locationDetail(location))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .textSelection(.enabled)
      }

      Spacer(minLength: 12)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
}

private struct InspectorGlassSection<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: systemImage)
        .font(.headline)
        .foregroundStyle(.secondary)

      content
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .keydexContentPanel(stroke: KeydexGlassTone.panelStroke, selected: false)
  }
}
