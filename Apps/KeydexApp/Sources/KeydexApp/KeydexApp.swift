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
        .accessibilityIdentifier("keydex.shell")
        .accessibilityLabel("Keydex credential inventory")
    }
    .defaultSize(
      width: Self.defaultWindowSize.width,
      height: Self.defaultWindowSize.height
    )
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
    _settingsConfig = State(initialValue: sampleSettingsData())
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
    return [
      .all,
      .state(.expiring),
      .state(.plaintextFallback),
      .state(.orphan),
      .state(.expired),
      .state(.duplicate),
    ] + services.map { .service($0) }
  }

  private var projectedCredentials: [CredentialProjection] {
    graph.credentialProjections
  }

  private var rows: [CredentialRow] {
    projectedCredentials(for: selectedSidebar)
      .filter { rowMatchesSearch($0) }
      .map(CredentialRow.init)
      .sorted { lhs, rhs in
        if lhs.service == rhs.service {
          return lhs.account < rhs.account
        }
        return lhs.service < rhs.service
      }
  }

  private var selectedProjection: CredentialProjection? {
    rows.first { $0.id == selectedCredentialID }
      .map(\.projection)
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
    NavigationSplitView {
      List(sidebarSelectionItems, id: \.self, selection: $selectedSidebar) { item in
        Label(item.title, systemImage: item.systemImage)
          .tag(item)
      }
      .listStyle(.sidebar)
      .accessibilityIdentifier("keydex.sidebar.scopes")
      .accessibilityLabel("Credential scopes")
      .navigationTitle("Scopes")
    } content: {
      VStack(spacing: 0) {
        ZStack {
          Table(rows, selection: $selectedCredentialID) {
            TableColumn("Service") { row in
              Text(row.service)
            }

            TableColumn("Account") { row in
              Text(row.account)
            }

            TableColumn("State") { row in
              Text(canonicalStateLabel(row.states))
            }

            TableColumn("Sources") { row in
              Text("\(row.locations.count)")
            }
          }
          .accessibilityIdentifier("keydex.inventory.table")
          .accessibilityLabel("Credential inventory table")
          .searchable(
            text: $searchText,
            prompt: isEmptyMode
              ? "No credentials to search"
              : "Find credentials"
          )
          .navigationTitle(selectedSidebar.title)
          .font(.system(.body, design: .monospaced))
          .frame(minHeight: 320)

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

        Divider()

        DoctorPanel(issues: doctorIssues, isEmptyMode: isEmptyMode)
      }
      .navigationSplitViewColumnWidth(min: 420, ideal: 460, max: 560)
    } detail: {
      VStack(alignment: .leading, spacing: 14) {
        if let projection = selectedProjection {
          Text("Credential")
            .font(.headline)

          VStack(alignment: .leading, spacing: 6) {
            Text("\(projection.ref.service.value)/\(projection.ref.account.value)")
              .font(.title3)
              .fontWeight(.medium)

            Text("States")
              .font(.subheadline)
              .fontWeight(.semibold)

            ForEach(projection.states, id: \.self) { state in
              Text(canonicalStateLabel([state]))
                .foregroundStyle(stateTint(for: state))
            }

            Text("Sources")
              .font(.subheadline)
              .fontWeight(.semibold)
              .padding(.top, 2)

            ForEach(projection.locations, id: \.self) { location in
              Text(locationLabel(location))
                .font(.callout)
                .textSelection(.enabled)
            }
          }
        } else {
          ContentUnavailableView(
            "Select a credential",
            systemImage: "list.bullet.indent",
            description: Text(
              isEmptyMode
                ? "Scan sources or add metadata to create new credentials."
                : "Choose an item from the table to inspect its graph-derived metadata."
            )
          )
        }
      }
      .padding(16)
      .frame(minWidth: 260)
      .accessibilityIdentifier("keydex.inspector")
      .accessibilityLabel("Credential inspector")
    }
    .toolbar {
      ToolbarItem(placement: .status) {
        Picker("Sample mode", selection: $inventoryMode) {
          ForEach(InventoryMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
        .help("Switch sample credential dataset")
        .accessibilityIdentifier("keydex.toolbar.inventory-mode")
        .accessibilityLabel("Inventory mode")
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

  private func projectedCredentials(for selection: SidebarSelection) -> [CredentialProjection] {
    switch selection {
    case .all:
      projectedCredentials
    case .state(let state):
      projectedCredentials.filter { $0.states.contains(state) }
    case .service(let service):
      projectedCredentials.filter { $0.ref.service.value == service }
    }
  }

  private func rowMatchesSearch(_ projection: CredentialProjection) -> Bool {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedQuery = trimmed.lowercased()
    let searchHaystack = [
      projection.ref.service.value,
      projection.ref.account.value,
      projection.states.map { $0.rawValue }.joined(separator: " "),
      projection.locations.map(locationLabel).joined(separator: " "),
    ]
    .joined(separator: " ")
    .lowercased()

    return trimmed.isEmpty || searchHaystack.contains(normalizedQuery)
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

private enum AppScreenScenario: String, CaseIterable {
  case defaultWindow = "default-window"
  case emptyInventory = "empty-inventory"
  case searchFilter = "search-filter"
  case inspector
  case settings
  case settingsSources = "settings-sources"
  case settingsPaths = "settings-paths"
  case settingsRules = "settings-rules"
  case compactWindow = "compact-window"

  static var supportedValues: String {
    allCases.map(\.rawValue).joined(separator: ", ")
  }

  var inventoryMode: InventoryMode {
    switch self {
    case .emptyInventory:
      .empty
    case .defaultWindow, .searchFilter, .inspector, .settings, .settingsSources,
      .settingsPaths, .settingsRules, .compactWindow:
      .sample
    }
  }

  var sidebarSelection: SidebarSelection {
    switch self {
    case .searchFilter:
      .state(.plaintextFallback)
    case .defaultWindow, .emptyInventory, .inspector, .settings, .settingsSources,
      .settingsPaths, .settingsRules, .compactWindow:
      .all
    }
  }

  var selectedCredentialID: CredentialRow.ID? {
    switch self {
    case .inspector:
      "hashicorp-vault|infra"
    case .defaultWindow, .emptyInventory, .searchFilter, .settings, .settingsSources,
      .settingsPaths, .settingsRules, .compactWindow:
      nil
    }
  }

  var searchText: String {
    switch self {
    case .searchFilter:
      "github"
    case .defaultWindow, .emptyInventory, .inspector, .settings, .settingsSources,
      .settingsPaths, .settingsRules, .compactWindow:
      ""
    }
  }

  var showsSettings: Bool {
    switch self {
    case .settings, .settingsSources, .settingsPaths, .settingsRules:
      true
    case .defaultWindow, .emptyInventory, .searchFilter, .inspector, .compactWindow:
      false
    }
  }

  var settingsSection: SettingsSection {
    switch self {
    case .settings:
      .permissions
    case .settingsSources:
      .sources
    case .settingsPaths:
      .paths
    case .settingsRules:
      .rules
    case .defaultWindow, .emptyInventory, .searchFilter, .inspector, .compactWindow:
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

private enum SidebarSelection: Hashable {
  case all
  case state(CredentialState)
  case service(String)

  var title: String {
    switch self {
    case .all:
      "All Credentials"
    case .state(let state):
      "State: \(state.rawValue)"
    case .service(let service):
      service
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
    }
  }
}

private struct CredentialRow: Identifiable {
  let projection: CredentialProjection

  var id: String {
    "\(projection.ref.service.value)|\(projection.ref.account.value)"
  }

  var service: String { projection.ref.service.value }
  var account: String { projection.ref.account.value }
  var states: [CredentialState] { projection.states }
  var locations: [CredentialLocation] { projection.locations }
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
    Array(issueRows.prefix(2))
  }

  private var remainingIssueCount: Int {
    max(issueRows.count - previewRows.count, 0)
  }

  private var remainingIssueSummary: String {
    let issueNoun = remainingIssueCount == 1 ? "issue" : "issues"
    return "\(remainingIssueCount) more \(issueNoun) in repair queue (\(issueRows.count) total)"
  }

  private var accessibilityHint: String {
    if issues.isEmpty {
      return "No repair issues are currently listed."
    }

    return "Showing \(previewRows.count) of \(issueRows.count) repair issues."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Doctor")
        .font(.headline)
        .padding(.horizontal, 12)
        .padding(.top, 10)

      if issues.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text(isEmptyMode ? "No issues" : "No issues found")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 2)

          if isEmptyMode {
            Text("Next action: scan sources or add metadata to inventory.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 12)
              .padding(.bottom, 8)
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(previewRows) { row in
            VStack(alignment: .leading, spacing: 4) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.severityLabel)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(row.severityTint)
                Text(row.credentialLabel)
                  .font(.subheadline)
                  .fontDesign(.monospaced)
                  .lineLimit(1)
                Spacer()
              }

              Text("state: \(row.stateLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)

              Text("cause: \(row.issue.message)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

              Text("action: \(row.issue.action)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.accessibilityLabel)

            if row.id != previewRows.last?.id {
              Divider()
                .padding(.leading, 12)
            }
          }

          if remainingIssueCount > 0 {
            Divider()
              .padding(.leading, 12)

            Text(remainingIssueSummary)
              .font(.caption.weight(.medium))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
          }
        }
      }
    }
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

private struct ShellSettingsConfig {
  var keychainAccess: Bool
  var requestPrompt: Bool
  var scanSources: [ScanSourceRow]
  var scanPaths: [EditableSettingsRow]
  var ignoredSources: [EditableSettingsRow]
  var unmanagedSources: [EditableSettingsRow]
}

private enum SettingsSection: String, CaseIterable, Identifiable {
  case permissions
  case sources
  case paths
  case rules

  var id: String { rawValue }

  var title: String {
    switch self {
    case .permissions:
      "Permissions"
    case .sources:
      "Sources"
    case .paths:
      "Paths"
    case .rules:
      "Rules"
    }
  }
}

private func sampleSettingsData() -> ShellSettingsConfig {
  ShellSettingsConfig(
    keychainAccess: true,
    requestPrompt: false,
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
    "\(settings.scanPaths.count) paths · \(settings.ignoredSources.count) ignored · \(settings.unmanagedSources.count) unmanaged"
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
        .buttonStyle(.borderless)
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
