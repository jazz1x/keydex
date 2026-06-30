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
    let view = NSView()
    DispatchQueue.main.async {
      apply(to: view)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context _: Context) {
    DispatchQueue.main.async {
      apply(to: nsView)
    }
  }

  private func apply(to view: NSView) {
    guard let size, let window = view.window else {
      return
    }

    var frame = window.frame
    frame.size = size
    window.setFrame(frame, display: true)
  }
}

struct CredentialInventoryShellView: View {
  @State private var selectedSidebar: SidebarSelection
  @State private var selectedCredentialID: CredentialRow.ID?
  @State private var searchText: String
  @State private var isShowingSettings: Bool
  @State private var inventoryMode: InventoryMode

  init() {
    let initialScenario = Self.screenScenarioFromEnvironment()
    let initialMode = Self.inventoryModeFromEnvironment(
      defaultingTo: initialScenario.inventoryMode
    )
    _selectedSidebar = State(initialValue: initialScenario.sidebarSelection)
    _selectedCredentialID = State(initialValue: initialScenario.selectedCredentialID)
    _searchText = State(initialValue: initialScenario.searchText)
    _isShowingSettings = State(initialValue: initialScenario.showsSettings)
    _inventoryMode = State(initialValue: initialMode)
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
      SettingsPanel(sample: sampleSettingsData())
        .frame(minWidth: 560, minHeight: 480)
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
  case compactWindow = "compact-window"

  static var supportedValues: String {
    allCases.map(\.rawValue).joined(separator: ", ")
  }

  var inventoryMode: InventoryMode {
    switch self {
    case .emptyInventory:
      .empty
    case .defaultWindow, .searchFilter, .inspector, .settings, .compactWindow:
      .sample
    }
  }

  var sidebarSelection: SidebarSelection {
    switch self {
    case .searchFilter:
      .state(.plaintextFallback)
    case .defaultWindow, .emptyInventory, .inspector, .settings, .compactWindow:
      .all
    }
  }

  var selectedCredentialID: CredentialRow.ID? {
    switch self {
    case .inspector:
      "hashicorp-vault|infra"
    case .defaultWindow, .emptyInventory, .searchFilter, .settings, .compactWindow:
      nil
    }
  }

  var searchText: String {
    switch self {
    case .searchFilter:
      "github"
    case .defaultWindow, .emptyInventory, .inspector, .settings, .compactWindow:
      ""
    }
  }

  var showsSettings: Bool {
    switch self {
    case .settings:
      true
    case .defaultWindow, .emptyInventory, .searchFilter, .inspector, .compactWindow:
      false
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
  let id = UUID()
  let title: String
  let detail: String
  let enabled: Bool
}

private struct ShellSettingsConfig {
  let keychainPermissionState: String
  let keychainAccess: Bool
  let requestPrompt: Bool
  let scanSources: [ScanSourceRow]
  let scanPaths: [String]
  let ignoredSources: [String]
  let unmanagedSources: [String]
}

private func sampleSettingsData() -> ShellSettingsConfig {
  ShellSettingsConfig(
    keychainPermissionState: "Read-only sample scope",
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
      "/Users/example/.zshrc",
      "/Users/example/.config/gh/config",
      "/Users/example/.aws/credentials",
    ],
    ignoredSources: [
      "~/Downloads/keys/legacy.env",
      "~/tmp/oneoff/.env.disabled",
    ],
    unmanagedSources: [
      "process:local-session-secret",
      "binary:legacy-auth-helper",
    ]
  )
}

private struct SettingsPanel: View {
  let sample: ShellSettingsConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Settings")
        .font(.title3.weight(.semibold))
        .padding(.top, 12)
        .padding(.horizontal, 16)

      Form {
        Section("Keychain Permission") {
          LabeledContent("Current status") {
            Text(sample.keychainPermissionState)
              .foregroundStyle(.secondary)
          }
          Toggle("Enable keychain access", isOn: .constant(sample.keychainAccess))
            .disabled(true)
          Toggle("Request runtime keychain prompt", isOn: .constant(sample.requestPrompt))
            .disabled(true)
        }

        Section("Scan Sources") {
          ForEach(sample.scanSources) { source in
            Toggle(isOn: .constant(source.enabled)) {
              VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                  .font(.subheadline)
                Text(source.detail)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .disabled(true)
          }
        }

        Section("Scan Paths") {
          ForEach(sample.scanPaths, id: \.self) { path in
            TextField("Path", text: .constant(path))
              .textFieldStyle(.roundedBorder)
              .disabled(true)
              .font(.system(.body, design: .monospaced))
          }
        }

        if !sample.ignoredSources.isEmpty || !sample.unmanagedSources.isEmpty {
          Section("Ignored / unmanaged sources") {
            if !sample.ignoredSources.isEmpty {
              Text("Ignored")
                .font(.subheadline.weight(.medium))
            }
            ForEach(sample.ignoredSources, id: \.self) { source in
              Text(source)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if !sample.unmanagedSources.isEmpty {
              Text("Unmanaged")
                .font(.subheadline.weight(.medium))
                .padding(.top, 4)
            }
            ForEach(sample.unmanagedSources, id: \.self) { source in
              Text(source)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .formStyle(.grouped)

      Spacer()
    }
    .padding(.horizontal, 4)
    .frame(minWidth: 520)
    .accessibilityIdentifier("keydex.settings.panel")
    .accessibilityLabel("Keydex settings")
  }
}
