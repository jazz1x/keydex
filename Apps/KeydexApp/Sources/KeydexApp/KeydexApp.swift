import AppKit
import KeydexCore
import SwiftUI

@main
struct KeydexApp: App {
  private static var windowPresetSize: CGSize? {
    guard let rawPreset = ProcessInfo.processInfo.environment["KEYDEX_APP_WINDOW_PRESET"] else {
      return nil
    }

    switch rawPreset {
    case "default":
      return CGSize(width: 1080, height: 680)
    case "compact":
      return CGSize(width: 900, height: 620)
    default:
      preconditionFailure(
        "Unsupported KEYDEX_APP_WINDOW_PRESET value: \(rawPreset). Expected 'default' or 'compact'."
      )
    }
  }

  private static var defaultWindowSize: CGSize {
    windowPresetSize ?? CGSize(width: 1080, height: 680)
  }

  var body: some Scene {
    WindowGroup("Keydex") {
      CredentialInventoryShellView()
        .background(WindowPresetApplier(size: Self.windowPresetSize))
        .onAppear {
          KeydexAppIcon.installApplicationIcon()
        }
        .accessibilityIdentifier("keydex.shell")
        .accessibilityLabel("Keydex credential inventory")
    }
    .defaultSize(
      width: Self.defaultWindowSize.width,
      height: Self.defaultWindowSize.height
    )
    .windowStyle(.hiddenTitleBar)

    MenuBarExtra {
      Button {
        NSApplication.shared.activate(ignoringOtherApps: true)
      } label: {
        Label("Open Keydex", systemImage: "macwindow")
      }

      Divider()

      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        Label("Quit Keydex", systemImage: "power")
      }
    } label: {
      Image(nsImage: KeydexAppIcon.trayTemplateImage())
        .accessibilityLabel("Keydex")
    }
    .menuBarExtraStyle(.menu)
  }
}

struct CredentialInventoryShellView: View {
  @Environment(\.appearsActive) private var appearsActive
  private let artworkStore: CredentialArtworkStore
  @State private var selectedSidebar: SidebarSelection
  @State private var selectedCredentialID: CredentialRow.ID?
  @State private var searchText: String
  @State private var isShowingSettings: Bool
  @State private var selectedSettingsSection: SettingsSection
  @State private var inventoryMode: InventoryMode
  @State private var settingsConfig: ShellSettingsConfig
  @State private var artworkOverrides: [CredentialArtworkID: CredentialArtworkOverride]
  @State private var artworkIssueMessage: String?

  init(artworkStore: CredentialArtworkStore = CredentialArtworkStore()) {
    let initialScenario = Self.screenScenarioFromEnvironment()
    let initialMode = Self.inventoryModeFromEnvironment(
      defaultingTo: initialScenario.inventoryMode
    )
    let artworkLoadState = artworkStore.loadOverrides()
    self.artworkStore = artworkStore
    _selectedSidebar = State(initialValue: initialScenario.sidebarSelection)
    _selectedCredentialID = State(initialValue: initialScenario.selectedCredentialID)
    _searchText = State(initialValue: initialScenario.searchText)
    _isShowingSettings = State(initialValue: initialScenario.showsSettings)
    _selectedSettingsSection = State(initialValue: initialScenario.settingsSection)
    _inventoryMode = State(initialValue: initialMode)
    _settingsConfig = State(
      initialValue: sampleSettingsData(
        displayMode: initialScenario.displayMode
      )
    )
    _artworkOverrides = State(initialValue: artworkLoadState.overrides)
    _artworkIssueMessage = State(initialValue: artworkLoadState.issueMessage)
  }

  fileprivate static func inventoryModeFromEnvironment(
    defaultingTo defaultMode: InventoryMode
  ) -> InventoryMode {
    guard let rawMode = ProcessInfo.processInfo.environment["KEYDEX_APP_INVENTORY_MODE"] else {
      return defaultMode
    }

    switch rawMode {
    case InventoryMode.sample.rawValue:
      return .sample
    case InventoryMode.empty.rawValue:
      return .empty
    default:
      preconditionFailure(
        "Unsupported KEYDEX_APP_INVENTORY_MODE value: \(rawMode). Expected 'sample' or 'empty'."
      )
    }
  }

  fileprivate static func screenScenarioFromEnvironment() -> AppScreenScenario {
    guard let rawScenario = ProcessInfo.processInfo.environment["KEYDEX_APP_SCREEN_SCENARIO"]
    else {
      return .defaultWindow
    }

    guard let scenario = AppScreenScenario(rawValue: rawScenario) else {
      preconditionFailure(
        "Unsupported KEYDEX_APP_SCREEN_SCENARIO value: \(rawScenario). Expected one of: \(AppScreenScenario.supportedValues)."
      )
    }

    return scenario
  }

  private var graph: InventoryGraph {
    switch inventoryMode {
    case .sample:
      sampleCredentialGraph()
    case .empty:
      InventoryGraph(records: [])
    }
  }

  private var isEmptyMode: Bool {
    inventoryMode == .empty
  }

  private var sidebarSelectionItems: [SidebarSelection] {
    let services = Set(graph.credentialProjections.map { $0.ref.service.value }).sorted()
    let tags = settingsConfig.tags
      .map { SidebarSelection.tag($0.name) }
      .sorted { $0.title < $1.title }
    return [
      .all,
      .state(.registered),
      .state(.missingKeychainItem),
      .state(.expiring),
      .state(.plaintextFallback),
      .state(.orphan),
      .state(.expired),
      .state(.duplicate),
    ] + services.map { .service($0) } + tags
  }

  private var projectedCredentials: [CredentialProjection] {
    graph.credentialProjections
  }

  private var rows: [CredentialRow] {
    projectedCredentials
      .map { projection in
        let credentialID = CredentialRow.identifier(for: projection)
        return CredentialRow(
          projection: projection,
          tags: tags(for: projection),
          artworkOverride: artworkOverrides[credentialID]
        )
      }
      .filter { rowMatchesSidebar($0, selectedSidebar) }
      .filter { rowMatchesSearch($0) }
      .sorted { lhs, rhs in
        if lhs.service == rhs.service {
          return lhs.account < rhs.account
        }
        return lhs.service < rhs.service
      }
  }

  private var selectedRow: CredentialRow? {
    rows.first { $0.id == selectedCredentialID }
  }

  private var doctorIssues: [DoctorIssue] {
    CredentialDoctor().inspect(graph).sorted {
      if $0.severity != $1.severity {
        return doctorSeverityOrder($0.severity) < doctorSeverityOrder($1.severity)
      }
      return "\($0.credential.service.value)/\($0.credential.account.value)"
        < "\($1.credential.service.value)/\($1.credential.account.value)"
    }
  }

  var body: some View {
    Group {
      if isCardLibrarySurface {
        NavigationSplitView {
          sidebarPane
        } detail: {
          inventoryPane
        }
      } else {
        NavigationSplitView {
          sidebarPane
        } content: {
          inventoryPane
            .navigationSplitViewColumnWidth(min: 480, ideal: 540, max: 640)
        } detail: {
          inspectorPane
        }
      }
    }
    .overlay {
      if isShowingSettings {
        ZStack {
          Color.black.opacity(settingsBackdropDimAlpha)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {}
            .transition(.opacity)
            .accessibilityHidden(true)

          SettingsPanel(
            settings: $settingsConfig,
            selectedSection: $selectedSettingsSection
          ) {
            withAnimation(KeydexMotion.contentTransition) {
              isShowingSettings = false
            }
          }
          .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
        .animation(KeydexMotion.contentTransition, value: isShowingSettings)
        .accessibilityIdentifier("keydex.settings.overlay")
      }
    }
    .alert("Artwork could not be updated", isPresented: artworkIssueBinding) {
      Button("OK", role: .cancel) {
        artworkIssueMessage = nil
      }
    } message: {
      Text(artworkIssueMessage ?? "The artwork library reported an unknown issue.")
    }
    .toolbar {
      ToolbarItem(placement: .status) {
        MusicToolbarCluster(
          inventoryMode: $inventoryMode,
          displayMode: $settingsConfig.displayMode
        )
        .keydexDisabledBehindSettings(isShowingSettings)
      }

      ToolbarItem(placement: .primaryAction) {
        Button {
          selectedSettingsSection = .permissions
          isShowingSettings = true
        } label: {
          Label("Register Keychain", systemImage: "key.fill")
        }
        .keydexGlassButton(prominent: true)
        .help("Add or manage Keychain references")
        .accessibilityIdentifier("keydex.toolbar.register-keychain")
        .accessibilityLabel("Register Keychain reference")
        .keydexDisabledBehindSettings(isShowingSettings)
      }

      ToolbarItem(placement: .primaryAction) {
        Button {
          isShowingSettings = true
        } label: {
          Label("Settings", systemImage: "gearshape.fill")
        }
        .help("Open app settings sample")
        .accessibilityIdentifier("keydex.toolbar.settings")
        .accessibilityLabel("Open settings")
        .keydexGlassButton()
        .keydexDisabledBehindSettings(isShowingSettings)
      }
    }
    .onChange(of: inventoryMode) { _, _ in
      selectedCredentialID = nil
    }
  }

  private var isCardLibrarySurface: Bool {
    settingsConfig.displayMode == .cards
  }

  private var settingsBackdropDimAlpha: Double {
    KeydexGlassTone.settingsBackdropDimAlpha(appearsActive: appearsActive)
  }

  private var sidebarPane: some View {
    MusicSidebarView(
      items: sidebarSelectionItems,
      selectedSidebar: $selectedSidebar,
      searchText: $searchText
    )
  }

  private var inventoryPane: some View {
    ZStack(alignment: .bottom) {
      InventoryContentView(
        rows: rows,
        title: selectedSidebar.title,
        searchText: searchText,
        displayMode: settingsConfig.displayMode,
        selectedCredentialID: $selectedCredentialID,
        isEmptyMode: isEmptyMode,
        footerReserveHeight: KeydexRailLayout.footerLaneHeight,
        artworkRootURL: artworkStore.rootURL
      ) {
        selectedSettingsSection = .permissions
        isShowingSettings = true
      } manageTagsAction: {
        selectedSettingsSection = .tags
        isShowingSettings = true
      } importArtworkAction: { sourceURL, row in
        importArtwork(from: sourceURL, for: row)
      } resetArtworkAction: { row in
        resetArtwork(for: row)
      } artworkFailureAction: { error in
        artworkIssueMessage = error.localizedDescription
      }
      .frame(minHeight: 320, maxHeight: .infinity)

      KeydexRailFooter {
        DoctorPanel(
          issues: doctorIssues,
          isEmptyMode: isEmptyMode
        ) { issue in
          reviewDoctorIssue(issue)
        }
      }
    }
  }

  private var inspectorPane: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let row = selectedRow {
        CredentialInspectorPanel(
          row: row,
          artworkRootURL: artworkStore.rootURL
        ) {
          selectedSettingsSection = .permissions
          isShowingSettings = true
        } manageTagsAction: {
          selectedSettingsSection = .tags
          isShowingSettings = true
        } importArtworkAction: { sourceURL, row in
          importArtwork(from: sourceURL, for: row)
        } resetArtworkAction: { row in
          resetArtwork(for: row)
        } artworkFailureAction: { error in
          artworkIssueMessage = error.localizedDescription
        }
      } else {
        ContentUnavailableView(
          "Select a credential",
          systemImage: "key.viewfinder",
          description: Text(
            isEmptyMode
              ? "Scan sources or add metadata to create new credentials."
              : "Choose an item from the \(settingsConfig.displayMode.inspectorSurfaceName) "
                + "to review its Keychain links, states, and sources."
          )
        )
      }
    }
    .padding(16)
    .frame(minWidth: 260)
    .accessibilityIdentifier("keydex.inspector")
    .accessibilityLabel("Credential inspector")
  }

  private func rowMatchesSidebar(_ row: CredentialRow, _ selection: SidebarSelection) -> Bool {
    switch selection {
    case .all:
      true
    case .state(let state):
      row.states.contains(state)
    case .service(let service):
      row.service == service
    case .tag(let tagName):
      row.tags.contains { $0.name.caseInsensitiveCompare(tagName) == .orderedSame }
    }
  }

  private func rowMatchesSearch(_ row: CredentialRow) -> Bool {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedQuery = trimmed.lowercased()
    let searchHaystack = [
      row.service,
      row.account,
      row.states.map { $0.rawValue }.joined(separator: " "),
      row.tags.map(\.name).joined(separator: " "),
      row.locations.map(locationLabel).joined(separator: " "),
    ]
    .joined(separator: " ")
    .lowercased()

    return trimmed.isEmpty || searchHaystack.contains(normalizedQuery)
  }

  private func reviewDoctorIssue(_ issue: DoctorIssueRow) {
    searchText = ""
    selectedSidebar = .all

    withAnimation(KeydexMotion.contentTransition) {
      settingsConfig.displayMode = .cards
      selectedCredentialID = issue.credentialID
    }
  }

  private var artworkIssueBinding: Binding<Bool> {
    Binding(
      get: { artworkIssueMessage != nil },
      set: { isPresented in
        if !isPresented {
          artworkIssueMessage = nil
        }
      }
    )
  }

  private func importArtwork(from sourceURL: URL, for row: CredentialRow) {
    let result = artworkStore.importArtwork(
      from: sourceURL,
      credentialID: row.id,
      existingOverrides: artworkOverrides
    )

    switch result {
    case .success(let override):
      artworkOverrides[row.id] = override
    case .failure(let error):
      artworkIssueMessage = error.localizedDescription
    }
  }

  private func resetArtwork(for row: CredentialRow) {
    let result = artworkStore.removeArtwork(
      for: row.id,
      existingOverrides: artworkOverrides
    )

    switch result {
    case .success:
      artworkOverrides.removeValue(forKey: row.id)
    case .failure(let error):
      artworkIssueMessage = error.localizedDescription
    }
  }

  private func tags(for projection: CredentialProjection) -> [CredentialTagRow] {
    let credentialID = CredentialRow.identifier(for: projection)
    return settingsConfig.tags.filter { tag in
      tag.matchesCredentialID(credentialID)
    }
  }
}

private struct KeydexSettingsModalToolbarBlocker: ViewModifier {
  let isShowingSettings: Bool

  func body(content: Content) -> some View {
    content
      .disabled(isShowingSettings)
      .allowsHitTesting(!isShowingSettings)
      .accessibilityHidden(isShowingSettings)
  }
}

extension View {
  fileprivate func keydexDisabledBehindSettings(_ isShowingSettings: Bool) -> some View {
    modifier(KeydexSettingsModalToolbarBlocker(isShowingSettings: isShowingSettings))
  }
}
