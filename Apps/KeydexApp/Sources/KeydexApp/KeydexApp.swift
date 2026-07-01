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

private enum KeydexAppIcon {
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

private struct WindowPresetApplier: NSViewRepresentable {
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

struct CredentialInventoryShellView: View {
  @State private var selectedSidebar: SidebarSelection
  @State private var selectedCredentialID: CredentialRow.ID?
  @State private var searchText: String
  @State private var isShowingSettings: Bool
  @State private var selectedSettingsSection: SettingsSection
  @State private var inventoryMode: InventoryMode
  @State private var settingsConfig: ShellSettingsConfig

  init() {
    let initialScenario = Self.screenScenarioFromEnvironment()
    let initialMode = Self.inventoryModeFromEnvironment(
      defaultingTo: initialScenario.inventoryMode
    )
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
        CredentialRow(projection: projection, tags: tags(for: projection))
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
    .toolbar {
      ToolbarItem(placement: .status) {
        MusicToolbarCluster(
          inventoryMode: $inventoryMode,
          displayMode: $settingsConfig.displayMode
        )
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
      }
    }
    .onChange(of: inventoryMode) { _, _ in
      selectedCredentialID = nil
    }
    .sheet(isPresented: $isShowingSettings) {
      SettingsPanel(
        settings: $settingsConfig,
        selectedSection: $selectedSettingsSection
      )
      .frame(width: 720, height: 520)
    }
  }

  private var isCardLibrarySurface: Bool {
    settingsConfig.displayMode == .cards
  }

  private var sidebarPane: some View {
    MusicSidebarView(
      items: sidebarSelectionItems,
      selectedSidebar: $selectedSidebar,
      searchText: $searchText
    )
  }

  private var inventoryPane: some View {
    VStack(spacing: 0) {
      InventoryContentView(
        rows: rows,
        title: selectedSidebar.title,
        searchText: searchText,
        displayMode: settingsConfig.displayMode,
        selectedCredentialID: $selectedCredentialID,
        isEmptyMode: isEmptyMode
      ) {
        selectedSettingsSection = .permissions
        isShowingSettings = true
      } manageTagsAction: {
        selectedSettingsSection = .tags
        isShowingSettings = true
      }
      .frame(minHeight: 320, maxHeight: .infinity)

      KeydexRailFooter {
        DoctorPanel(
          issues: doctorIssues,
          isEmptyMode: isEmptyMode
        )
      }
    }
  }

  private var inspectorPane: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let row = selectedRow {
        CredentialInspectorPanel(
          row: row
        ) {
          selectedSettingsSection = .permissions
          isShowingSettings = true
        } manageTagsAction: {
          selectedSettingsSection = .tags
          isShowingSettings = true
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

  private func tags(for projection: CredentialProjection) -> [CredentialTagRow] {
    let credentialID = CredentialRow.identifier(for: projection)
    return settingsConfig.tags.filter { tag in
      tag.matchesCredentialID(credentialID)
    }
  }
}

private struct KeydexRailFooter<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    ZStack(alignment: .center) {
      KeydexRailLaneBackground()

      content
        .padding(.horizontal, KeydexRailLayout.horizontalMargin)
        .padding(.top, KeydexRailLayout.footerTopPadding)
        .padding(.bottom, KeydexRailLayout.footerBottomPadding)
        .frame(maxWidth: .infinity)
    }
    .frame(height: KeydexRailLayout.footerLaneHeight)
    .accessibilityElement(children: .contain)
  }
}

private struct KeydexRailLaneBackground: View {
  var body: some View {
    ZStack {
      Rectangle()
        .fill(.ultraThinMaterial)

      Rectangle()
        .fill(KeydexGlassTone.railLaneWash)

      Rectangle()
        .fill(KeydexGlassTone.railLaneMilkyHighlight)
    }
    .overlay(alignment: .top) {
      Rectangle()
        .fill(.separator.opacity(KeydexRailLayout.footerSeparatorAlpha))
        .frame(height: 1)
    }
  }
}

private struct MusicToolbarCluster: View {
  @Binding var inventoryMode: InventoryMode
  @Binding var displayMode: InventoryDisplayMode

  var body: some View {
    HStack(spacing: 10) {
      Picker("Sample mode", selection: $inventoryMode) {
        ForEach(InventoryMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 154)
      .help("Switch sample credential dataset")
      .accessibilityIdentifier("keydex.toolbar.inventory-mode")
      .accessibilityLabel("Inventory mode")

      Divider()
        .frame(height: 22)

      Picker("Display mode", selection: $displayMode) {
        ForEach(InventoryDisplayMode.allCases) { mode in
          Label(mode.title, systemImage: mode.systemImage).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 164)
      .help("Switch between list and card inventory views")
      .accessibilityIdentifier("keydex.toolbar.display-mode")
      .accessibilityLabel("Display mode")
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .keydexControlGlassPanel(cornerRadius: 18)
    .accessibilityIdentifier("keydex.toolbar.mode-cluster")
    .accessibilityLabel("Inventory and display controls")
  }
}

private struct MusicSidebarView: View {
  let items: [SidebarSelection]
  @Binding var selectedSidebar: SidebarSelection
  @Binding var searchText: String

  private var inventoryItems: [SidebarSelection] {
    [.all, .state(.missingKeychainItem), .state(.plaintextFallback)]
  }

  private var libraryItems: [SidebarSelection] {
    [
      .state(.registered),
      .state(.orphan),
      .state(.expiring),
      .state(.expired),
      .state(.duplicate),
    ]
  }

  private var serviceItems: [SidebarSelection] {
    items.compactMap { item in
      if case .service = item {
        return item
      }

      return nil
    }
  }

  private var tagItems: [SidebarSelection] {
    items.compactMap { item in
      if case .tag = item {
        return item
      }

      return nil
    }
  }

  var body: some View {
    ScrollViewReader { scrollProxy in
      ScrollView {
        VStack(alignment: .leading, spacing: KeydexSidebarLayout.sectionSpacing) {
          Color.clear
            .frame(height: 0)
            .accessibilityHidden(true)
            .id(KeydexSidebarScrollAnchor.top)

          MusicSearchField(searchText: $searchText)
            .padding(.horizontal, 4)
            .padding(.top, KeydexSidebarLayout.searchTopPadding)

          MusicSidebarSection(title: nil) {
            ForEach(inventoryItems, id: \.self) { item in
              MusicSidebarRow(
                item: item,
                selected: selectedSidebar == item
              ) {
                selectedSidebar = item
              }
            }
          }

          MusicSidebarSection(title: "Library") {
            ForEach(libraryItems, id: \.self) { item in
              MusicSidebarRow(
                item: item,
                selected: selectedSidebar == item
              ) {
                selectedSidebar = item
              }
            }
          }

          if !tagItems.isEmpty {
            MusicSidebarSection(title: "Tags") {
              ForEach(tagItems, id: \.self) { item in
                MusicSidebarRow(
                  item: item,
                  selected: selectedSidebar == item
                ) {
                  selectedSidebar = item
                }
              }
            }
          }

          MusicSidebarSection(title: "Services") {
            ForEach(serviceItems, id: \.self) { item in
              MusicSidebarRow(
                item: item,
                selected: selectedSidebar == item
              ) {
                selectedSidebar = item
              }
            }
          }
        }
        .padding(.horizontal, KeydexSidebarLayout.contentHorizontalPadding)
        .padding(.bottom, KeydexSidebarLayout.contentBottomPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(KeydexSidebarWashLayer())
      }
      .scrollContentBackground(.hidden)
      .onAppear {
        scrollProxy.scrollTo(KeydexSidebarScrollAnchor.top, anchor: .top)
      }
    }
    .keydexSidebarGlass()
    .accessibilityIdentifier("keydex.sidebar.scopes")
    .accessibilityLabel("Credential scopes")
    .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
  }
}

private struct MusicSearchField: View {
  @Binding var searchText: String

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass")
        .font(.body)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      TextField("Search", text: $searchText)
        .textFieldStyle(.plain)
        .font(.body)
        .accessibilityLabel("Search credentials")

      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.body)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Clear search")
        .accessibilityLabel("Clear search")
      }
    }
    .keydexSidebarSearchRow()
    .accessibilityIdentifier("keydex.sidebar.search")
  }
}

private struct MusicSidebarSection<Content: View>: View {
  let title: String?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: KeydexSidebarLayout.titleSpacing) {
      if let title {
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 4)
      }

      VStack(alignment: .leading, spacing: KeydexSidebarLayout.rowSpacing) {
        content
      }
    }
  }
}

private struct MusicSidebarRow: View {
  let item: SidebarSelection
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(item.title, systemImage: item.systemImage)
        .font(.body.weight(selected ? .semibold : .regular))
        .foregroundStyle(selected ? Color.accentColor : .primary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KeydexSidebarLayout.rowHorizontalPadding)
        .frame(height: KeydexSidebarLayout.rowHeight)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.plain)
    .help(item.title)
  }

  @ViewBuilder private var rowBackground: some View {
    if selected {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(KeydexGlassTone.sidebarSelectionFill)
    }
  }
}

private enum InventoryMode: String, CaseIterable, Identifiable {
  case sample
  case empty

  var id: String { rawValue }

  var title: String {
    switch self {
    case .sample:
      "Sample"
    case .empty:
      "Empty"
    }
  }
}

private enum InventoryDisplayMode: String, CaseIterable, Identifiable, Hashable {
  case list
  case cards

  var id: String { rawValue }

  var title: String {
    switch self {
    case .list:
      "List"
    case .cards:
      "Cards"
    }
  }

  var systemImage: String {
    switch self {
    case .list:
      "list.bullet.rectangle"
    case .cards:
      "rectangle.grid.2x2"
    }
  }

  var inspectorSurfaceName: String {
    switch self {
    case .list:
      "table"
    case .cards:
      "card grid"
    }
  }
}

private enum AppScreenScenario: String, CaseIterable {
  case defaultWindow = "default-window"
  case cardView = "card-view"
  case cardDetail = "card-detail"
  case emptyInventory = "empty-inventory"
  case searchFilter = "search-filter"
  case inspector
  case settings
  case settingsAppearance = "settings-appearance"
  case settingsSources = "settings-sources"
  case settingsPaths = "settings-paths"
  case settingsTags = "settings-tags"
  case settingsRules = "settings-rules"
  case compactWindow = "compact-window"

  static var supportedValues: String {
    allCases.map(\.rawValue).joined(separator: ", ")
  }

  var inventoryMode: InventoryMode {
    switch self {
    case .emptyInventory:
      .empty
    case .defaultWindow, .cardView, .cardDetail, .searchFilter, .inspector, .settings,
      .settingsAppearance, .settingsSources, .settingsPaths, .settingsTags, .settingsRules,
      .compactWindow:
      .sample
    }
  }

  var displayMode: InventoryDisplayMode {
    switch self {
    case .cardView, .cardDetail:
      .cards
    case .defaultWindow, .emptyInventory, .searchFilter, .inspector, .settings,
      .settingsAppearance, .settingsSources, .settingsPaths, .settingsTags, .settingsRules,
      .compactWindow:
      .list
    }
  }

  var sidebarSelection: SidebarSelection {
    switch self {
    case .searchFilter:
      .state(.plaintextFallback)
    case .defaultWindow, .cardView, .cardDetail, .emptyInventory, .inspector, .settings,
      .settingsAppearance, .settingsSources, .settingsPaths, .settingsTags, .settingsRules,
      .compactWindow:
      .all
    }
  }

  var selectedCredentialID: CredentialRow.ID? {
    switch self {
    case .cardDetail:
      "aws|ci"
    case .inspector:
      "hashicorp-vault|infra"
    case .defaultWindow, .cardView, .emptyInventory, .searchFilter, .settings,
      .settingsAppearance, .settingsSources, .settingsPaths, .settingsTags, .settingsRules,
      .compactWindow:
      nil
    }
  }

  var searchText: String {
    switch self {
    case .searchFilter:
      "github"
    case .defaultWindow, .cardView, .cardDetail, .emptyInventory, .inspector, .settings,
      .settingsAppearance, .settingsSources, .settingsPaths, .settingsTags, .settingsRules,
      .compactWindow:
      ""
    }
  }

  var showsSettings: Bool {
    switch self {
    case .settings, .settingsAppearance, .settingsSources, .settingsPaths, .settingsTags,
      .settingsRules:
      true
    case .defaultWindow, .cardView, .cardDetail, .emptyInventory, .searchFilter, .inspector,
      .compactWindow:
      false
    }
  }

  var settingsSection: SettingsSection {
    switch self {
    case .settings:
      .permissions
    case .settingsAppearance:
      .appearance
    case .settingsSources:
      .sources
    case .settingsPaths:
      .paths
    case .settingsTags:
      .tags
    case .settingsRules:
      .rules
    case .defaultWindow, .cardView, .cardDetail, .emptyInventory, .searchFilter, .inspector,
      .compactWindow:
      .permissions
    }
  }
}

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
  }
}

private struct InventoryContentView: View {
  let rows: [CredentialRow]
  let title: String
  let searchText: String
  let displayMode: InventoryDisplayMode
  @Binding var selectedCredentialID: CredentialRow.ID?
  let isEmptyMode: Bool
  let manageKeychainAction: () -> Void
  let manageTagsAction: () -> Void

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
      case .cards:
        if let selectedCardRow {
          CredentialMusicDetailView(
            row: selectedCardRow,
            manageKeychainAction: manageKeychainAction,
            manageTagsAction: manageTagsAction
          ) {
            selectedCredentialID = nil
          }
        } else {
          CredentialCardGrid(
            rows: rows,
            title: title,
            searchText: searchText,
            selectedCredentialID: $selectedCredentialID
          )
        }
      }

      if rows.isEmpty {
        EmptyStatePanel(
          title: "No credentials",
          systemImage: "tray",
          description: isEmptyMode
            ? "This dataset is intentionally empty."
            : "No matching rows for the selected scope.",
          secondaryText: isEmptyMode
            ? "Scan sources or add metadata to populate credentials."
            : "Try adjusting your scope or search query."
        )
      }
    }
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
  @Binding var selectedCredentialID: CredentialRow.ID?

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
                  isSelected: selectedCredentialID == row.id
                ) {
                  selectedCredentialID = row.id
                }
              }
            }
          }
        }
        .padding(.horizontal, KeydexCardGridLayout.contentHorizontalPadding)
        .padding(.top, KeydexCardGridLayout.contentTopPadding)
        .padding(.bottom, KeydexCardGridLayout.contentBottomPadding)
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
  let isSelected: Bool
  let selectAction: () -> Void

  var body: some View {
    Button(action: selectAction) {
      VStack(alignment: .leading, spacing: KeydexCardGridLayout.posterToTextSpacing) {
        CredentialArtworkPanel(
          row: row,
          height: KeydexCardGridLayout.posterHeight,
          selected: isSelected
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
    .accessibilityLabel(row.cardAccessibilityLabel)
  }
}

private struct CredentialArtworkPanel: View {
  let row: CredentialRow
  var height: CGFloat = 82
  var selected = false

  var body: some View {
    ZStack {
      panelShape
        .keydexArtworkGlass(tint: panelFill, stroke: panelStroke)
        .overlay {
          if isPoster {
            CredentialPosterWash(accentColor: accentColor)
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

      Image(systemName: row.keychainStatusSystemImage)
        .font(
          .system(
            size: isPoster
              ? KeydexCardArtworkLayout.posterSymbolSize
              : KeydexCardArtworkLayout.compactSymbolSize,
            weight: .semibold
          )
        )
        .foregroundStyle(accentColor)
        .symbolRenderingMode(.hierarchical)
        .opacity(isPoster ? KeydexGlassTone.posterSymbolAlpha : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }
    .frame(height: height)
  }

  private var panelFill: Color {
    accentColor.opacity(KeydexGlassTone.artworkColorAlpha)
  }

  private var panelStroke: Color {
    if selected {
      return Color.accentColor.opacity(0.74)
    }

    return accentColor.opacity(isPoster ? 0.18 : 0.12)
  }

  private var panelRadius: CGFloat {
    isPoster ? 8 : 6
  }

  private var isPoster: Bool {
    height > 120
  }

  private var accentColor: Color {
    credentialAccent(for: row.states)
  }

  private var panelShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: panelRadius, style: .continuous)
  }
}

private struct CredentialPosterWash: View {
  let accentColor: Color

  var body: some View {
    ZStack(alignment: .top) {
      Rectangle()
        .fill(accentColor.opacity(KeydexGlassTone.posterWashHighAlpha))

      Rectangle()
        .fill(Color.white.opacity(KeydexGlassTone.posterHighlightAlpha))
        .frame(height: 42)
    }
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
    Label(tag.name, systemImage: "tag.fill")
      .font(compact ? .caption2.weight(.medium) : .caption.weight(.medium))
      .labelStyle(.titleAndIcon)
      .foregroundStyle(tag.color.tint)
      .lineLimit(1)
      .padding(.horizontal, compact ? 6 : 8)
      .padding(.vertical, compact ? 3 : 4)
      .background(tag.color.tint.opacity(KeydexGlassTone.metadataChipFillAlpha), in: Capsule())
      .overlay {
        Capsule()
          .stroke(
            tag.color.tint.opacity(KeydexGlassTone.metadataChipStrokeAlpha),
            lineWidth: 1
          )
      }
  }
}

private struct CredentialInspectorPanel: View {
  let row: CredentialRow
  let manageKeychainAction: () -> Void
  let manageTagsAction: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        CredentialArtworkPanel(row: row)
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
          .keydexGlassButton(prominent: true)
          .help("Open Keychain reference management")
          .accessibilityIdentifier("keydex.inspector.manage-keychain")
          .accessibilityLabel("Manage Keychain reference")

          KeychainStatusBadge(row: row)
        }

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
            .keydexGlassButton()
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
  let manageKeychainAction: () -> Void
  let manageTagsAction: () -> Void
  let closeAction: () -> Void

  var body: some View {
    ZStack {
      InventoryBackdropView()

      ScrollView {
        VStack(alignment: .leading, spacing: KeydexCardDetailLayout.sectionSpacing) {
          Button(action: closeAction) {
            Label("Credential Library", systemImage: "chevron.left")
          }
          .font(.callout.weight(.semibold))
          .foregroundStyle(.secondary)
          .buttonStyle(.plain)
          .help("Return to credential library")
          .accessibilityIdentifier("keydex.card-detail.back")

          HStack(alignment: .bottom, spacing: KeydexCardDetailLayout.headerSpacing) {
            CredentialArtworkPanel(
              row: row,
              height: KeydexCardDetailLayout.artworkSize,
              selected: true
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
                .keydexGlassButton(prominent: true)

                Button(action: manageTagsAction) {
                  Label("Manage Tags", systemImage: "tag.fill")
                }
                .keydexGlassButton()
                .help("Open tag management")
                .accessibilityIdentifier("keydex.card-detail.manage-tags")
                .accessibilityLabel("Manage credential tags")

                KeychainStatusBadge(row: row)
              }
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
        .padding(.bottom, KeydexCardDetailLayout.contentBottomPadding)
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

private enum SidebarSelection: Hashable {
  case all
  case state(CredentialState)
  case service(String)
  case tag(String)

  var title: String {
    switch self {
    case .all:
      "All Credentials"
    case .state(.registered):
      "Registered"
    case .state(.missingKeychainItem):
      "Missing"
    case .state(.plaintextFallback):
      "Plaintext"
    case .state(.orphan):
      "Orphan"
    case .state(.expiring):
      "Expiring"
    case .state(.expired):
      "Expired"
    case .state(.duplicate):
      "Duplicate"
    case .service(let service):
      service
    case .tag(let tagName):
      tagName
    }
  }

  var systemImage: String {
    switch self {
    case .all:
      "rectangle.grid.2x2"
    case .state(.expiring):
      "clock.badge.exclamationmark"
    case .state(.plaintextFallback):
      "doc.plaintext"
    case .state(.orphan):
      "person.crop.circle.badge.exclamationmark"
    case .state(.expired):
      "exclamationmark.octagon"
    case .state(.duplicate):
      "doc.on.doc"
    case .state:
      "circle.dashed"
    case .service:
      "server.rack"
    case .tag:
      "tag"
    }
  }
}

private struct CredentialRow: Identifiable {
  let projection: CredentialProjection
  let tags: [CredentialTagRow]

  init(projection: CredentialProjection, tags: [CredentialTagRow] = []) {
    self.projection = projection
    self.tags = tags
  }

  static func identifier(for projection: CredentialProjection) -> String {
    "\(projection.ref.service.value)|\(projection.ref.account.value)"
  }

  var id: String {
    Self.identifier(for: projection)
  }

  var service: String { projection.ref.service.value }
  var account: String { projection.ref.account.value }
  var states: [CredentialState] { projection.states }
  var locations: [CredentialLocation] { projection.locations }

  var keychainLocationCount: Int {
    locations.filter { location in
      if case .keychain = location {
        return true
      }

      return false
    }.count
  }

  var locationPreview: [CredentialLocation] {
    Array(locations.prefix(2))
  }

  var primaryLocationTitle: String {
    locations.first.map(locationLabel) ?? "No source location"
  }

  var keychainStatusTitle: String {
    if states.contains(.missingKeychainItem) {
      return "Missing"
    }

    if states.contains(.orphan), keychainLocationCount > 0 {
      return "Orphan"
    }

    if keychainLocationCount > 0 {
      return "Linked"
    }

    return "Not linked"
  }

  var keychainStatusSystemImage: String {
    if states.contains(.missingKeychainItem) {
      return "key.slash"
    }

    if states.contains(.orphan) {
      return "key.viewfinder"
    }

    if keychainLocationCount > 0 {
      return "key.fill"
    }

    return "key"
  }

  var cardCaptionLine: String {
    if let primaryTag = tags.first {
      let taggedState = "#\(primaryTag.name) · \(canonicalStateLabel(states))"
      return "\(account) · \(taggedState) · \(keychainStatusTitle)"
    }

    return "\(account) · \(canonicalStateLabel(states)) · \(keychainStatusTitle)"
  }

  var cardAccessibilityLabel: String {
    let tagSummary: String
    if tags.isEmpty {
      tagSummary = "no tags"
    } else {
      tagSummary = "tags \(tags.map(\.name).joined(separator: ", "))"
    }

    let stateSummary = canonicalStateLabel(states)
    return "\(service) \(account), states \(stateSummary), \(tagSummary), "
      + "Keychain \(keychainStatusTitle), \(locations.count) sources."
  }
}

private func canonicalStateLabel(_ states: [CredentialState]) -> String {
  states.map(\.rawValue).sorted().joined(separator: ", ")
}

private struct DoctorIssueRow: Identifiable {
  let issue: DoctorIssue

  var id: String {
    "\(issue.credential.service.value)|\(issue.credential.account.value)|\(issue.state.rawValue)"
  }

  var severityLabel: String {
    issue.severity.rawValue
  }

  var credentialLabel: String {
    "\(issue.credential.service.value)/\(issue.credential.account.value)"
  }

  var stateLabel: String {
    canonicalStateLabel([issue.state])
  }

  var severityTint: Color {
    doctorSeverityTint(issue.severity)
  }

  var accessibilityLabel: String {
    "\(severityLabel) issue for \(credentialLabel). State: \(stateLabel). Cause: \(issue.message). Action: \(issue.action)."
  }
}

private struct DoctorPanel: View {
  let issues: [DoctorIssue]
  let isEmptyMode: Bool

  private var issueRows: [DoctorIssueRow] {
    issues.map(DoctorIssueRow.init)
  }

  private var previewRows: [DoctorIssueRow] {
    Array(issueRows.prefix(1))
  }

  private var primaryIssue: DoctorIssueRow? {
    previewRows.first
  }

  private var remainingIssueCount: Int {
    max(issueRows.count - previewRows.count, 0)
  }

  private var accessibilityHint: String {
    if issues.isEmpty {
      return "No repair issues are currently listed."
    }

    return "Showing \(previewRows.count) of \(issueRows.count) repair issues."
  }

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      Label {
        Text("Doctor")
          .font(.headline)
      } icon: {
        Image(systemName: issues.isEmpty ? "checkmark.seal" : "stethoscope")
          .font(.body.weight(.semibold))
          .frame(width: 30, height: 30)
          .background(KeydexGlassTone.railControlFill, in: Circle())
      }
      .foregroundStyle(issues.isEmpty ? .green : .primary)

      Divider()
        .frame(height: 24)

      if let primaryIssue {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 7) {
            Text(primaryIssue.severityLabel)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(primaryIssue.severityTint)
            Text(primaryIssue.credentialLabel)
              .font(.subheadline)
              .fontDesign(.monospaced)
              .lineLimit(1)
          }

          Text(primaryIssue.issue.action)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(primaryIssue.accessibilityLabel)
      } else {
        VStack(alignment: .leading, spacing: 3) {
          Text(isEmptyMode ? "Ready for sources" : "No issues found")
            .font(.subheadline)
          Text(isEmptyMode ? "Scan sources or add metadata." : "Inventory is healthy.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 12)

      if issues.isEmpty {
        Label("Clear", systemImage: "checkmark.circle.fill")
          .font(.caption.weight(.medium))
          .foregroundStyle(.green)
      } else {
        Text("\(issueRows.count) issues")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)

        if remainingIssueCount > 0 {
          Text("+\(remainingIssueCount)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(KeydexGlassTone.railControlFill, in: Capsule())
        }
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 8)
    .frame(
      maxWidth: KeydexRailLayout.maxWidth,
      minHeight: KeydexRailLayout.railHeight,
      alignment: .center
    )
    .keydexFloatingGlassPanel(
      tint: KeydexGlassTone.railFloatingTint,
      stroke: KeydexGlassTone.railFloatingStroke
    )
    .accessibilityIdentifier("keydex.doctor.panel")
    .accessibilityLabel("Credential repair queue")
    .accessibilityHint(accessibilityHint)
  }
}

private func stateTint(for state: CredentialState) -> Color {
  switch state {
  case .missingKeychainItem, .expired:
    .red
  case .plaintextFallback, .orphan, .expiring, .duplicate:
    .orange
  case .registered:
    .green
  }
}

private func stateSystemImage(for state: CredentialState) -> String {
  switch state {
  case .registered:
    "checkmark.seal"
  case .missingKeychainItem:
    "key.slash"
  case .plaintextFallback:
    "doc.plaintext"
  case .orphan:
    "person.crop.circle.badge.exclamationmark"
  case .expiring:
    "clock.badge.exclamationmark"
  case .expired:
    "exclamationmark.octagon"
  case .duplicate:
    "doc.on.doc"
  }
}

private func credentialAccent(for states: [CredentialState]) -> Color {
  if states.contains(.missingKeychainItem) || states.contains(.expired) {
    return .red
  }

  if states.contains(.plaintextFallback) || states.contains(.orphan) || states.contains(.expiring)
    || states.contains(.duplicate)
  {
    return .orange
  }

  if states.contains(.registered) {
    return .green
  }

  return .secondary
}

private func keychainTint(for row: CredentialRow) -> Color {
  if row.states.contains(.missingKeychainItem) {
    return .red
  }

  if row.states.contains(.orphan) {
    return .orange
  }

  if row.keychainLocationCount > 0 {
    return .green
  }

  return .secondary
}

private func keychainTint(for projection: CredentialProjection) -> Color {
  keychainTint(for: CredentialRow(projection: projection))
}

private func keychainCount(for projection: CredentialProjection) -> Int {
  CredentialRow(projection: projection).keychainLocationCount
}

private func keychainSummary(for projection: CredentialProjection) -> String {
  let row = CredentialRow(projection: projection)
  let count = row.keychainLocationCount

  if row.states.contains(.missingKeychainItem) {
    return "Metadata references a missing Keychain item"
  }

  if row.states.contains(.orphan), count > 0 {
    return "Keychain item has no Keydex metadata"
  }

  if count == 1 {
    return "1 Keychain item linked"
  }

  if count > 1 {
    return "\(count) Keychain items linked"
  }

  return "No Keychain reference linked"
}

private func doctorSeverityOrder(_ severity: DoctorSeverity) -> Int {
  switch severity {
  case .error:
    0
  case .warning:
    1
  case .info:
    2
  }
}

private func doctorSeverityTint(_ severity: DoctorSeverity) -> Color {
  switch severity {
  case .error:
    .red
  case .warning:
    .orange
  case .info:
    .blue
  }
}

private func locationLabel(_ location: CredentialLocation) -> String {
  switch location {
  case .keychain(let service, let account):
    "\(service.value)/\(account.value) (keychain)"
  case .environment(let name):
    "env: \(name.value)"
  case .shellProfile(let path):
    "shell profile: \(path.value)"
  case .configFile(let path):
    "config file: \(path.value)"
  }
}

private func locationKindTitle(_ location: CredentialLocation) -> String {
  switch location {
  case .keychain:
    "Keychain"
  case .environment:
    "Environment"
  case .shellProfile:
    "Shell profile"
  case .configFile:
    "Config file"
  }
}

private func locationDetail(_ location: CredentialLocation) -> String {
  switch location {
  case .keychain(let service, let account):
    "\(service.value)/\(account.value)"
  case .environment(let name):
    name.value
  case .shellProfile(let path):
    path.value
  case .configFile(let path):
    path.value
  }
}

private func locationSystemImage(_ location: CredentialLocation) -> String {
  switch location {
  case .keychain:
    "key.fill"
  case .environment:
    "terminal"
  case .shellProfile:
    "chevron.left.forwardslash.chevron.right"
  case .configFile:
    "doc.text"
  }
}

private func sampleCredentialGraph() -> InventoryGraph {
  do {
    let openaiRef = try CredentialRef.parse(service: "openai", account: "default")
    let awsRef = try CredentialRef.parse(service: "aws", account: "ci")
    let githubRef = try CredentialRef.parse(service: "github", account: "work")
    let vaultRef = try CredentialRef.parse(service: "hashicorp-vault", account: "infra")
    let npmRef = try CredentialRef.parse(service: "npm", account: "scoped")

    let records: [CredentialRecord] = [
      CredentialRecord(
        ref: openaiRef,
        state: .registered,
        locations: [
          .keychain(service: openaiRef.service, account: openaiRef.account)
        ]
      ),
      CredentialRecord(
        ref: awsRef,
        state: .missingKeychainItem,
        locations: [
          .environment(name: try NonEmptyText.parse("AWS_ACCESS_KEY_ID", field: "name"))
        ]
      ),
      CredentialRecord(
        ref: githubRef,
        state: .plaintextFallback,
        locations: [
          .configFile(path: try NonEmptyText.parse("~/.config/gh/config", field: "path"))
        ]
      ),
      CredentialRecord(
        ref: vaultRef,
        state: .expired,
        locations: [
          .shellProfile(path: try NonEmptyText.parse("~/.zshrc", field: "path")),
          .environment(name: try NonEmptyText.parse("VAULT_TOKEN", field: "name")),
        ]
      ),
      CredentialRecord(
        ref: npmRef,
        state: .orphan,
        locations: [
          .keychain(service: npmRef.service, account: npmRef.account)
        ]
      ),
      CredentialRecord(
        ref: try CredentialRef.parse(service: "acme", account: "staging"),
        state: .duplicate,
        locations: [
          .environment(name: try NonEmptyText.parse("ACME_API_KEY", field: "name"))
        ]
      ),
      CredentialRecord(
        ref: try CredentialRef.parse(service: "expiring-service", account: "preview"),
        state: .expiring,
        locations: [
          .configFile(path: try NonEmptyText.parse("~/.expiring/config", field: "path"))
        ]
      ),
    ]

    return InventoryGraph(records: records)
  } catch {
    preconditionFailure("Invalid checked-in sample credential graph: \(error)")
  }
}

private struct ScanSourceRow: Identifiable {
  let id: UUID
  var title: String
  var detail: String
  var enabled: Bool

  init(id: UUID = UUID(), title: String, detail: String, enabled: Bool) {
    self.id = id
    self.title = title
    self.detail = detail
    self.enabled = enabled
  }

  var accessibilitySuffix: String {
    title
      .lowercased()
      .replacingOccurrences(of: " ", with: "-")
  }

  var systemImage: String {
    switch accessibilitySuffix {
    case "keychain":
      "key.fill"
    case "shell-profiles":
      "terminal"
    case "environment-variables":
      "curlybraces"
    case "config-files":
      "doc.text"
    default:
      "circle.grid.2x2"
    }
  }
}

private struct EditableSettingsRow: Identifiable {
  let id: UUID
  var value: String

  init(id: UUID = UUID(), _ value: String) {
    self.id = id
    self.value = value
  }
}

private struct CredentialTagRow: Identifiable, Hashable {
  let id: UUID
  var name: String
  var assignments: String
  var color: CredentialTagColor

  init(
    id: UUID = UUID(),
    name: String,
    assignments: String,
    color: CredentialTagColor
  ) {
    self.id = id
    self.name = name
    self.assignments = assignments
    self.color = color
  }

  var credentialIDs: [String] {
    assignments
      .components(separatedBy: CharacterSet(charactersIn: ",\n"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  func matchesCredentialID(_ credentialID: String) -> Bool {
    credentialIDs.contains { assignedID in
      assignedID.caseInsensitiveCompare(credentialID) == .orderedSame
    }
  }
}

private enum CredentialTagColor: String, CaseIterable, Identifiable, Hashable {
  case accent
  case red
  case orange
  case green
  case blue
  case gray

  var id: String { rawValue }

  var title: String {
    switch self {
    case .accent:
      "Accent"
    case .red:
      "Red"
    case .orange:
      "Orange"
    case .green:
      "Green"
    case .blue:
      "Blue"
    case .gray:
      "Gray"
    }
  }

  var tint: Color {
    switch self {
    case .accent:
      .accentColor
    case .red:
      .red
    case .orange:
      .orange
    case .green:
      .green
    case .blue:
      .blue
    case .gray:
      .secondary
    }
  }
}

private struct ShellSettingsConfig {
  var keychainAccess: Bool
  var requestPrompt: Bool
  var displayMode: InventoryDisplayMode
  var keychainReferences: [EditableSettingsRow]
  var scanSources: [ScanSourceRow]
  var scanPaths: [EditableSettingsRow]
  var tags: [CredentialTagRow]
  var ignoredSources: [EditableSettingsRow]
  var unmanagedSources: [EditableSettingsRow]
}

private enum SettingsSection: String, CaseIterable, Identifiable {
  case permissions
  case appearance
  case sources
  case paths
  case tags
  case rules

  var id: String { rawValue }

  var title: String {
    switch self {
    case .permissions:
      "Permissions"
    case .appearance:
      "Appearance"
    case .sources:
      "Sources"
    case .paths:
      "Paths"
    case .tags:
      "Tags"
    case .rules:
      "Rules"
    }
  }
}

private func sampleSettingsData(displayMode: InventoryDisplayMode = .list) -> ShellSettingsConfig {
  ShellSettingsConfig(
    keychainAccess: true,
    requestPrompt: false,
    displayMode: displayMode,
    keychainReferences: [
      EditableSettingsRow("openai/default"),
      EditableSettingsRow("npm/scoped"),
    ],
    scanSources: [
      ScanSourceRow(
        title: "Keychain",
        detail: "Read metadata from macOS keychain entries generated by apps",
        enabled: true
      ),
      ScanSourceRow(
        title: "Shell profiles",
        detail: "Parse ~/.zshrc and ~/.bashrc for export statements",
        enabled: true
      ),
      ScanSourceRow(
        title: "Environment variables",
        detail: "Enumerate non-secret environment values with credential-like names",
        enabled: false
      ),
      ScanSourceRow(
        title: "Config files",
        detail: "Inspect service config files in common locations",
        enabled: true
      ),
    ],
    scanPaths: [
      EditableSettingsRow("/Users/example/.zshrc"),
      EditableSettingsRow("/Users/example/.config/gh/config"),
      EditableSettingsRow("/Users/example/.aws/credentials"),
    ],
    tags: [
      CredentialTagRow(
        name: "CI",
        assignments: "aws|ci, github|work",
        color: .blue
      ),
      CredentialTagRow(
        name: "Rotates Soon",
        assignments: "expiring-service|preview, hashicorp-vault|infra",
        color: .orange
      ),
      CredentialTagRow(
        name: "Personal",
        assignments: "openai|default",
        color: .accent
      ),
    ],
    ignoredSources: [
      EditableSettingsRow("~/Downloads/keys/legacy.env"),
      EditableSettingsRow("~/tmp/oneoff/.env.disabled"),
    ],
    unmanagedSources: [
      EditableSettingsRow("process:local-session-secret"),
      EditableSettingsRow("binary:legacy-auth-helper"),
    ]
  )
}

private struct SettingsPanel: View {
  @Binding var settings: ShellSettingsConfig
  @Binding var selectedSection: SettingsSection

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
              .font(.title2.weight(.semibold))
            Text(settingsSummary)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          HStack(spacing: 8) {
            SettingsStatusPill(
              title: "Keychain",
              value: settings.keychainAccess ? "On" : "Off",
              systemImage: settings.keychainAccess ? "key.fill" : "key.slash"
            )
            SettingsStatusPill(
              title: "Sources",
              value: "\(enabledSourceCount)/\(settings.scanSources.count)",
              systemImage: "checklist"
            )
            SettingsStatusPill(
              title: "Tags",
              value: "\(settings.tags.count)",
              systemImage: "tag"
            )
          }
        }

        Picker("Settings section", selection: $selectedSection) {
          ForEach(SettingsSection.allCases) { section in
            Text(section.title).tag(section)
          }
        }
        .pickerStyle(.segmented)
        .padding(4)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("keydex.settings.section-picker")
        .accessibilityLabel("Settings section")
      }
      .padding(.horizontal, 24)
      .padding(.top, 20)
      .padding(.bottom, 16)
      .background(.regularMaterial)
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(.separator.opacity(0.45))
          .frame(height: 1)
      }

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          switch selectedSection {
          case .permissions:
            SettingsGlassSection(
              title: "Keychain Permission",
              subtitle: keychainPermissionStatus,
              systemImage: "key.fill"
            ) {
              SettingsToggleRow(
                title: "Enable keychain access",
                subtitle: "Include Keychain references in local inventory scans",
                systemImage: "lock.open",
                isOn: $settings.keychainAccess,
                accessibilityIdentifier: "keydex.settings.keychain-access"
              )

              SettingsDivider()

              SettingsToggleRow(
                title: "Request runtime keychain prompt",
                subtitle: "Ask before a scan reads Keychain item references",
                systemImage: "hand.raised",
                isOn: $settings.requestPrompt,
                accessibilityIdentifier: "keydex.settings.request-prompt"
              )
            }

            EditableSettingsListSection(
              title: "Keychain References",
              subtitle: "\(settings.keychainReferences.count) tracked",
              systemImage: "key.fill",
              textFieldLabel: "service/account",
              addLabel: "Add keychain reference",
              removeLabel: "Remove keychain reference",
              rows: $settings.keychainReferences,
              monospace: true,
              valueFieldIdentifier: "keydex.settings.keychain-reference.value",
              draftFieldIdentifier: "keydex.settings.keychain-reference.draft",
              addButtonIdentifier: "keydex.settings.add-keychain-reference",
              removeButtonIdentifier: "keydex.settings.remove-keychain-reference"
            )

          case .appearance:
            SettingsGlassSection(
              title: "Appearance",
              subtitle: "\(settings.displayMode.title) · System light/dark",
              systemImage: "sparkles"
            ) {
              SettingsDisplayModeRow(selection: $settings.displayMode)
            }

          case .sources:
            SettingsGlassSection(
              title: "Scan Sources",
              subtitle: "\(enabledSourceCount) enabled",
              systemImage: "checklist"
            ) {
              ForEach($settings.scanSources) { $source in
                SettingsToggleRow(
                  title: source.title,
                  subtitle: source.detail,
                  systemImage: source.systemImage,
                  isOn: $source.enabled,
                  accessibilityIdentifier:
                    "keydex.settings.scan-source.\(source.accessibilitySuffix)"
                )

                if source.id != settings.scanSources.last?.id {
                  SettingsDivider()
                }
              }
            }

          case .paths:
            EditableSettingsListSection(
              title: "Scan Paths",
              subtitle: "\(settings.scanPaths.count) paths",
              systemImage: "folder",
              textFieldLabel: "Path",
              addLabel: "Add scan path",
              removeLabel: "Remove scan path",
              rows: $settings.scanPaths,
              monospace: true,
              valueFieldIdentifier: "keydex.settings.scan-path.value",
              draftFieldIdentifier: "keydex.settings.scan-path.draft",
              addButtonIdentifier: "keydex.settings.add-scan-path",
              removeButtonIdentifier: "keydex.settings.remove-scan-path"
            )

          case .tags:
            EditableTagListSection(tags: $settings.tags)

          case .rules:
            EditableSettingsListSection(
              title: "Ignored Sources",
              subtitle: "\(settings.ignoredSources.count) ignored",
              systemImage: "eye.slash",
              textFieldLabel: "Source",
              addLabel: "Add ignored source",
              removeLabel: "Remove ignored source",
              rows: $settings.ignoredSources,
              monospace: false,
              valueFieldIdentifier: "keydex.settings.ignored-source.value",
              draftFieldIdentifier: "keydex.settings.ignored-source.draft",
              addButtonIdentifier: "keydex.settings.add-ignored-source",
              removeButtonIdentifier: "keydex.settings.remove-ignored-source"
            )
            EditableSettingsListSection(
              title: "Unmanaged Sources",
              subtitle: "\(settings.unmanagedSources.count) unmanaged",
              systemImage: "tray",
              textFieldLabel: "Source",
              addLabel: "Add unmanaged source",
              removeLabel: "Remove unmanaged source",
              rows: $settings.unmanagedSources,
              monospace: false,
              valueFieldIdentifier: "keydex.settings.unmanaged-source.value",
              draftFieldIdentifier: "keydex.settings.unmanaged-source.draft",
              addButtonIdentifier: "keydex.settings.add-unmanaged-source",
              removeButtonIdentifier: "keydex.settings.remove-unmanaged-source"
            )
          }
        }
        .padding(24)
      }
      .background(.ultraThinMaterial)
    }
    .frame(width: 720, height: 520)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .accessibilityIdentifier("keydex.settings.panel")
    .accessibilityLabel("Keydex settings")
  }

  private var enabledSourceCount: Int {
    settings.scanSources.filter(\.enabled).count
  }

  private var settingsSummary: String {
    "\(settings.displayMode.title) · \(settings.tags.count) tags · \(settings.scanPaths.count) paths · \(settings.ignoredSources.count) ignored"
  }

  private var keychainPermissionStatus: String {
    if settings.keychainAccess {
      return "Enabled for inventory scan runs"
    }

    return "Disabled for inventory scan runs"
  }
}

private struct EditableSettingsListSection: View {
  let title: String
  let subtitle: String
  let systemImage: String
  let textFieldLabel: String
  let addLabel: String
  let removeLabel: String
  @Binding var rows: [EditableSettingsRow]
  var monospace: Bool
  let valueFieldIdentifier: String
  let draftFieldIdentifier: String
  let addButtonIdentifier: String
  let removeButtonIdentifier: String
  @State private var draftValue = ""

  var body: some View {
    SettingsGlassSection(title: title, subtitle: subtitle, systemImage: systemImage) {
      ForEach($rows) { $row in
        SettingsEditableRow(
          textFieldLabel: textFieldLabel,
          removeLabel: removeLabel,
          text: $row.value,
          monospace: monospace,
          valueFieldIdentifier: valueFieldIdentifier,
          removeButtonIdentifier: removeButtonIdentifier
        ) {
          rows.removeAll { $0.id == row.id }
        }

        if row.id != rows.last?.id {
          SettingsDivider()
        }
      }

      if !rows.isEmpty {
        SettingsDivider()
      }

      HStack(alignment: .center, spacing: 10) {
        Image(systemName: "plus.circle.fill")
          .font(.body.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 24)

        TextField(textFieldLabel, text: $draftValue)
          .textFieldStyle(.plain)
          .font(monospace ? .system(.body, design: .monospaced) : .body)
          .accessibilityIdentifier(draftFieldIdentifier)
          .accessibilityLabel(textFieldLabel)

        Button {
          addDraftValue()
        } label: {
          Label(addLabel, systemImage: "plus")
        }
        .keydexGlassButton()
        .labelStyle(.iconOnly)
        .help(addLabel)
        .accessibilityLabel(addLabel)
        .accessibilityIdentifier(addButtonIdentifier)
        .disabled(trimmedDraftValue.isEmpty)
      }
      .padding(.vertical, 8)
    }
  }

  private var trimmedDraftValue: String {
    draftValue.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func addDraftValue() {
    rows.append(EditableSettingsRow(trimmedDraftValue))
    draftValue = ""
  }
}

private struct EditableTagListSection: View {
  @Binding var tags: [CredentialTagRow]
  @State private var draftName = ""
  @State private var draftAssignments = ""
  @State private var draftColor = CredentialTagColor.accent

  var body: some View {
    SettingsGlassSection(
      title: "Credential Tags",
      subtitle: "\(tags.count) user-managed tags",
      systemImage: "tag.fill"
    ) {
      ForEach($tags) { $tag in
        SettingsTagEditableRow(tag: $tag) {
          tags.removeAll { $0.id == tag.id }
        }

        if tag.id != tags.last?.id {
          SettingsDivider()
        }
      }

      if !tags.isEmpty {
        SettingsDivider()
      }

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .center, spacing: 10) {
          Image(systemName: "plus.circle.fill")
            .font(.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 24)

          TextField("Tag name", text: $draftName)
            .textFieldStyle(.plain)
            .font(.body)
            .accessibilityIdentifier("keydex.settings.tag.draft-name")
            .accessibilityLabel("New tag name")

          Picker("Tag color", selection: $draftColor) {
            ForEach(CredentialTagColor.allCases) { color in
              Text(color.title).tag(color)
            }
          }
          .labelsHidden()
          .frame(width: 118)
          .accessibilityIdentifier("keydex.settings.tag.draft-color")
          .accessibilityLabel("New tag color")

          Button {
            addDraftTag()
          } label: {
            Label("Add tag", systemImage: "plus")
          }
          .keydexGlassButton()
          .labelStyle(.iconOnly)
          .help("Add tag")
          .accessibilityLabel("Add tag")
          .accessibilityIdentifier("keydex.settings.add-tag")
          .disabled(trimmedDraftName.isEmpty)
        }

        HStack(spacing: 10) {
          Color.clear
            .frame(width: 24)
            .accessibilityHidden(true)

          TextField("service|account, service|account", text: $draftAssignments)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .accessibilityIdentifier("keydex.settings.tag.draft-assignments")
            .accessibilityLabel("New tag credential assignments")
        }
      }
      .padding(.vertical, 8)
    }
  }

  private var trimmedDraftName: String {
    draftName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedDraftAssignments: String {
    draftAssignments.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func addDraftTag() {
    tags.append(
      CredentialTagRow(
        name: trimmedDraftName,
        assignments: trimmedDraftAssignments,
        color: draftColor
      )
    )
    draftName = ""
    draftAssignments = ""
    draftColor = .accent
  }
}

private struct SettingsTagEditableRow: View {
  @Binding var tag: CredentialTagRow
  let removeAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center, spacing: 10) {
        Image(systemName: "tag.fill")
          .font(.body.weight(.medium))
          .foregroundStyle(tag.color.tint)
          .frame(width: 24)

        TextField("Tag name", text: $tag.name)
          .textFieldStyle(.plain)
          .font(.body)
          .accessibilityIdentifier("keydex.settings.tag.name")
          .accessibilityLabel("Tag name")

        Picker("Tag color", selection: $tag.color) {
          ForEach(CredentialTagColor.allCases) { color in
            Text(color.title).tag(color)
          }
        }
        .labelsHidden()
        .frame(width: 118)
        .accessibilityIdentifier("keydex.settings.tag.color")
        .accessibilityLabel("Tag color")

        Button {
          removeAction()
        } label: {
          Label("Remove tag", systemImage: "minus")
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .help("Remove tag")
        .accessibilityLabel("Remove tag")
        .accessibilityIdentifier("keydex.settings.remove-tag")
      }

      HStack(spacing: 10) {
        Color.clear
          .frame(width: 24)
          .accessibilityHidden(true)

        TextField("service|account assignments", text: $tag.assignments)
          .textFieldStyle(.plain)
          .font(.system(.body, design: .monospaced))
          .accessibilityIdentifier("keydex.settings.tag.assignments")
          .accessibilityLabel("Tag credential assignments")
      }
    }
    .padding(.vertical, 8)
  }
}

private struct SettingsDisplayModeRow: View {
  @Binding var selection: InventoryDisplayMode

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: "rectangle.grid.2x2")
        .font(.body.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 3) {
        Text("Display mode")
          .font(.body)
        Text("Choose dense rows or scannable cards without changing graph truth")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 12)

      Picker("Display mode", selection: $selection) {
        ForEach(InventoryDisplayMode.allCases) { mode in
          Label(mode.title, systemImage: mode.systemImage).tag(mode)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(width: 180)
      .accessibilityIdentifier("keydex.settings.display-mode")
      .accessibilityLabel("Display mode")
    }
    .padding(.vertical, 8)
  }
}

private struct SettingsStatusPill: View {
  let title: String
  let value: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.caption.weight(.semibold))
      Text(title)
      Text(value)
        .foregroundStyle(.secondary)
    }
    .font(.caption.weight(.medium))
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.thinMaterial, in: Capsule())
    .overlay {
      Capsule()
        .stroke(.separator.opacity(0.5), lineWidth: 1)
    }
  }
}

private struct SettingsGlassSection<Content: View>: View {
  let title: String
  let subtitle: String
  let systemImage: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Image(systemName: systemImage)
          .font(.body.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.headline)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }

      VStack(spacing: 0) {
        content
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(.separator.opacity(0.55), lineWidth: 1)
      }
    }
  }
}

private struct SettingsToggleRow: View {
  let title: String
  let subtitle: String
  let systemImage: String
  @Binding var isOn: Bool
  let accessibilityIdentifier: String

  var body: some View {
    Toggle(isOn: $isOn) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: systemImage)
          .font(.body.weight(.medium))
          .foregroundStyle(.secondary)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.body)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.vertical, 8)
    }
    .toggleStyle(.switch)
    .help(subtitle)
    .accessibilityIdentifier(accessibilityIdentifier)
  }
}

private struct SettingsEditableRow: View {
  let textFieldLabel: String
  let removeLabel: String
  @Binding var text: String
  var monospace: Bool
  let valueFieldIdentifier: String
  let removeButtonIdentifier: String
  let removeAction: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: monospace ? "folder" : "line.3.horizontal.decrease.circle")
        .font(.body.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(width: 24)

      TextField(textFieldLabel, text: $text)
        .textFieldStyle(.plain)
        .font(monospace ? .system(.body, design: .monospaced) : .body)
        .accessibilityIdentifier(valueFieldIdentifier)
        .accessibilityLabel(textFieldLabel)

      Button {
        removeAction()
      } label: {
        Label(removeLabel, systemImage: "minus")
      }
      .buttonStyle(.borderless)
      .labelStyle(.iconOnly)
      .help(removeLabel)
      .accessibilityLabel(removeLabel)
      .accessibilityIdentifier(removeButtonIdentifier)
    }
    .padding(.vertical, 8)
  }
}

private struct SettingsDivider: View {
  var body: some View {
    Rectangle()
      .fill(.separator.opacity(0.55))
      .frame(height: 1)
      .padding(.leading, 34)
  }
}

private enum KeydexGlassTone {
  static let sidebarMilkyWashLight = Color(red: 0.99, green: 0.99, blue: 0.97).opacity(0.86)
  static let sidebarMilkyWashDark = Color.white.opacity(0.08)
  static let sidebarSelectionFill = Color.primary.opacity(0.045)
  static let contentPanelFill = Color.primary.opacity(0.020)
  static let contentGlassTint = Color.white.opacity(0.06)
  static let controlGlassTint = Color.white.opacity(0.10)
  static let floatingTint = Color.white.opacity(0.20)
  static let railLaneWash = Color(nsColor: .windowBackgroundColor).opacity(0.62)
  static let railLaneMilkyHighlight = Color.white.opacity(0.16)
  static let railFloatingTint = Color(nsColor: .windowBackgroundColor).opacity(0.46)
  static let railFloatingStroke = Color(nsColor: .separatorColor).opacity(0.22)
  static let railControlFill = Color.primary.opacity(0.045)
  static let panelStroke = Color(nsColor: .separatorColor).opacity(0.30)
  static let stateChipFillAlpha = 0.08
  static let stateChipStrokeAlpha = 0.24
  static let metadataChipFillAlpha = 0.07
  static let metadataChipStrokeAlpha = 0.22
  static let metadataChipFill = Color.primary.opacity(0.045)
  static let posterBadgeFill = Color.primary.opacity(0.045)
  static let posterBadgeStroke = Color(nsColor: .separatorColor).opacity(0.22)
  static let artworkColorAlpha = 0.18
  static let posterSymbolAlpha = 0.50
  static let posterWashHighAlpha = 0.03
  static let posterHighlightAlpha = 0.06
}

private enum KeydexRailLayout {
  static let horizontalMargin: CGFloat = 24
  static let footerLaneHeight: CGFloat = 90
  static let footerTopPadding: CGFloat = 12
  static let footerBottomPadding: CGFloat = 16
  static let footerSeparatorAlpha = 0.12
  static let railHeight: CGFloat = 58
  static let maxWidth: CGFloat = 760
  static let cornerRadius: CGFloat = 29
}

private enum KeydexCardArtworkLayout {
  static let posterSymbolSize: CGFloat = 50
  static let compactSymbolSize: CGFloat = 34
}

private enum KeydexCardDetailLayout {
  static let artworkSize: CGFloat = 224
  static let contentHorizontalPadding: CGFloat = 24
  static let contentTopPadding: CGFloat = 18
  static let contentBottomPadding: CGFloat = 24
  static let sectionSpacing: CGFloat = 18
  static let headerSpacing: CGFloat = 24
  static let titleStackSpacing: CGFloat = 10
}

private enum KeydexCardGridLayout {
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

private enum KeydexSidebarLayout {
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

private enum KeydexSidebarScrollAnchor {
  static let top = "keydex.sidebar.top"
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

private struct KeydexFloatingGlassPanelModifier: ViewModifier {
  let tint: Color
  let stroke: Color

  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: KeydexRailLayout.cornerRadius, style: .continuous)

    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        content
          .glassEffect(.regular.tint(tint).interactive(), in: shape)
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
    view.blendingMode = .behindWindow
    view.state = .active
    view.isEmphasized = false
  }
}

private struct KeydexSidebarWashLayer: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    sidebarMilkyWash
      .allowsHitTesting(false)
  }

  private var sidebarMilkyWash: Color {
    colorScheme == .dark
      ? KeydexGlassTone.sidebarMilkyWashDark
      : KeydexGlassTone.sidebarMilkyWashLight
  }
}

private struct KeydexSidebarGlassModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  func body(content: Content) -> some View {
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        ZStack(alignment: .topLeading) {
          sidebarMilkyWash
            .ignoresSafeArea(edges: .top)
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
      sidebarMilkyWash
        .ignoresSafeArea(edges: .top)
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

  private var sidebarMilkyWash: Color {
    colorScheme == .dark
      ? KeydexGlassTone.sidebarMilkyWashDark
      : KeydexGlassTone.sidebarMilkyWashLight
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
  fileprivate func keydexGlassButton(prominent: Bool = false) -> some View {
    modifier(KeydexGlassButtonModifier(prominent: prominent))
  }

  fileprivate func keydexContentPanel(stroke: Color, selected: Bool) -> some View {
    modifier(
      KeydexContentPanelModifier(
        stroke: stroke,
        selected: selected
      )
    )
  }

  fileprivate func keydexArtworkGlass(tint: Color, stroke: Color) -> some View {
    modifier(KeydexArtworkGlassModifier(tint: tint, stroke: stroke))
  }

  fileprivate func keydexControlGlassPanel(cornerRadius: CGFloat) -> some View {
    modifier(KeydexControlGlassPanelModifier(cornerRadius: cornerRadius))
  }

  fileprivate func keydexFloatingGlassPanel(tint: Color, stroke: Color) -> some View {
    modifier(KeydexFloatingGlassPanelModifier(tint: tint, stroke: stroke))
  }

  fileprivate func keydexSidebarGlass() -> some View {
    modifier(KeydexSidebarGlassModifier())
  }

  fileprivate func keydexSidebarSearchRow() -> some View {
    modifier(KeydexSidebarSearchRowModifier())
  }
}
