import Foundation
import KeydexCore
import SwiftUI

enum InventoryMode: String, CaseIterable, Identifiable {
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

enum InventoryDisplayMode: String, CaseIterable, Codable, Identifiable, Hashable {
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

enum AppScreenScenario: String, CaseIterable {
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
    case .defaultWindow, .cardView, .cardDetail:
      .cards
    case .emptyInventory, .searchFilter, .inspector, .settings,
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

enum SidebarSelection: Hashable {
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

struct CredentialRow: Identifiable {
  let projection: CredentialProjection
  let tags: [CredentialTagRow]
  let artworkOverride: CredentialArtworkOverride?

  init(
    projection: CredentialProjection,
    tags: [CredentialTagRow] = [],
    artworkOverride: CredentialArtworkOverride? = nil
  ) {
    self.projection = projection
    self.tags = tags
    self.artworkOverride = artworkOverride
  }

  static func identifier(for ref: CredentialRef) -> String {
    "\(ref.service.value)|\(ref.account.value)"
  }

  static func identifier(for projection: CredentialProjection) -> String {
    identifier(for: projection.ref)
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

  var artworkPreset: CredentialArtworkPreset {
    credentialArtworkPreset(for: self)
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
    let artworkSummary = artworkOverride == nil ? "default artwork" : "custom artwork"
    return "\(service) \(account), states \(stateSummary), \(tagSummary), "
      + "Keychain \(keychainStatusTitle), \(locations.count) sources, \(artworkSummary)."
  }
}

struct CredentialArtworkPreset {
  let title: String
  let symbolName: String
  let monogram: String
  let primaryTint: Color
  let secondaryTint: Color
  let tertiaryTint: Color

  static let cloud = CredentialArtworkPreset(
    title: "Cloud key",
    symbolName: "cloud.fill",
    monogram: "CL",
    primaryTint: Color(red: 0.92, green: 0.48, blue: 0.22),
    secondaryTint: Color(red: 0.98, green: 0.77, blue: 0.46),
    tertiaryTint: Color(red: 0.47, green: 0.69, blue: 0.95)
  )

  static let code = CredentialArtworkPreset(
    title: "Developer token",
    symbolName: "chevron.left.forwardslash.chevron.right",
    monogram: "DV",
    primaryTint: Color(red: 0.39, green: 0.55, blue: 0.95),
    secondaryTint: Color(red: 0.43, green: 0.82, blue: 0.80),
    tertiaryTint: Color(red: 0.62, green: 0.54, blue: 0.86)
  )

  static let vault = CredentialArtworkPreset(
    title: "Vault reference",
    symbolName: "lock.rectangle.stack.fill",
    monogram: "VT",
    primaryTint: Color(red: 0.37, green: 0.62, blue: 0.55),
    secondaryTint: Color(red: 0.72, green: 0.80, blue: 0.66),
    tertiaryTint: Color(red: 0.42, green: 0.51, blue: 0.65)
  )

  static let terminal = CredentialArtworkPreset(
    title: "Shell source",
    symbolName: "terminal.fill",
    monogram: "SH",
    primaryTint: Color(red: 0.33, green: 0.36, blue: 0.40),
    secondaryTint: Color(red: 0.62, green: 0.82, blue: 0.35),
    tertiaryTint: Color(red: 0.43, green: 0.53, blue: 0.76)
  )

  static let personal = CredentialArtworkPreset(
    title: "Personal key",
    symbolName: "person.crop.circle.fill",
    monogram: "ME",
    primaryTint: Color(red: 0.72, green: 0.47, blue: 0.84),
    secondaryTint: Color(red: 0.93, green: 0.62, blue: 0.74),
    tertiaryTint: Color(red: 0.52, green: 0.72, blue: 0.92)
  )

  static let keyring = CredentialArtworkPreset(
    title: "Keyring default",
    symbolName: "key.fill",
    monogram: "KD",
    primaryTint: Color(red: 0.48, green: 0.61, blue: 0.57),
    secondaryTint: Color(red: 0.72, green: 0.76, blue: 0.68),
    tertiaryTint: Color(red: 0.58, green: 0.68, blue: 0.76)
  )

  static let repair = CredentialArtworkPreset(
    title: "Needs repair",
    symbolName: "key.slash.fill",
    monogram: "RX",
    primaryTint: Color(red: 0.95, green: 0.35, blue: 0.38),
    secondaryTint: Color(red: 0.95, green: 0.68, blue: 0.66),
    tertiaryTint: Color(red: 0.91, green: 0.55, blue: 0.40)
  )
}

func credentialArtworkPreset(for row: CredentialRow) -> CredentialArtworkPreset {
  if row.states.contains(.missingKeychainItem) || row.states.contains(.expired) {
    return .repair
  }

  let haystack = [row.service, row.account, row.tags.map(\.name).joined(separator: " ")]
    .joined(separator: " ")
    .lowercased()

  if haystack.contains("aws") || haystack.contains("cloud") {
    return .cloud
  }

  if haystack.contains("vault") || haystack.contains("secret") {
    return .vault
  }

  if haystack.contains("github") || haystack.contains("git") || haystack.contains("ci") {
    return .code
  }

  if haystack.contains("shell") || haystack.contains("terminal") || haystack.contains("zsh") {
    return .terminal
  }

  if haystack.contains("personal") || haystack.contains("openai") {
    return .personal
  }

  return .keyring
}

func canonicalStateLabel(_ states: [CredentialState]) -> String {
  states.map(\.rawValue).sorted().joined(separator: ", ")
}

struct DoctorIssueRow: Identifiable {
  let issue: DoctorIssue

  var id: String {
    "\(issue.credential.service.value)|\(issue.credential.account.value)|\(issue.state.rawValue)"
  }

  var credentialID: CredentialRow.ID {
    CredentialRow.identifier(for: issue.credential)
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

func stateTint(for state: CredentialState) -> Color {
  switch state {
  case .missingKeychainItem, .expired:
    .red
  case .plaintextFallback, .orphan, .expiring, .duplicate:
    .orange
  case .registered:
    .green
  }
}

func stateSystemImage(for state: CredentialState) -> String {
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

func credentialAccent(for states: [CredentialState]) -> Color {
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

func keychainTint(for row: CredentialRow) -> Color {
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

func keychainTint(for projection: CredentialProjection) -> Color {
  keychainTint(for: CredentialRow(projection: projection))
}

func keychainCount(for projection: CredentialProjection) -> Int {
  CredentialRow(projection: projection).keychainLocationCount
}

func keychainSummary(for projection: CredentialProjection) -> String {
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

func doctorSeverityOrder(_ severity: DoctorSeverity) -> Int {
  switch severity {
  case .error:
    0
  case .warning:
    1
  case .info:
    2
  }
}

func doctorSeverityTint(_ severity: DoctorSeverity) -> Color {
  switch severity {
  case .error:
    .red
  case .warning:
    .orange
  case .info:
    .blue
  }
}

func locationLabel(_ location: CredentialLocation) -> String {
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

func locationKindTitle(_ location: CredentialLocation) -> String {
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

func locationDetail(_ location: CredentialLocation) -> String {
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

func locationSystemImage(_ location: CredentialLocation) -> String {
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

func sampleCredentialGraph() -> InventoryGraph {
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

struct ScanSourceRow: Equatable, Identifiable {
  let id: UUID
  let persistenceID: String
  var title: String
  var detail: String
  var enabled: Bool

  init(
    id: UUID = UUID(),
    persistenceID: String,
    title: String,
    detail: String,
    enabled: Bool
  ) {
    self.id = id
    self.persistenceID = persistenceID
    self.title = title
    self.detail = detail
    self.enabled = enabled
  }

  static func == (left: ScanSourceRow, right: ScanSourceRow) -> Bool {
    left.persistenceID == right.persistenceID
      && left.title == right.title
      && left.detail == right.detail
      && left.enabled == right.enabled
  }

  var accessibilitySuffix: String {
    persistenceID
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

struct EditableSettingsRow: Codable, Equatable, Identifiable {
  let id: UUID
  var value: String

  init(id: UUID = UUID(), _ value: String) {
    self.id = id
    self.value = value
  }
}

struct CredentialTagRow: Codable, Identifiable, Hashable {
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

enum CredentialTagColor: String, CaseIterable, Codable, Identifiable, Hashable {
  case accent
  case red
  case orange
  case green
  case teal
  case blue
  case purple
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
    case .teal:
      "Teal"
    case .blue:
      "Blue"
    case .purple:
      "Purple"
    case .gray:
      "Gray"
    }
  }

  var tint: Color {
    switch self {
    case .accent:
      .accentColor
    case .red:
      Color(red: 0.86, green: 0.24, blue: 0.31)
    case .orange:
      Color(red: 0.88, green: 0.48, blue: 0.20)
    case .green:
      Color(red: 0.34, green: 0.62, blue: 0.43)
    case .teal:
      Color(red: 0.22, green: 0.61, blue: 0.64)
    case .blue:
      Color(red: 0.22, green: 0.48, blue: 0.88)
    case .purple:
      Color(red: 0.56, green: 0.43, blue: 0.80)
    case .gray:
      .secondary
    }
  }
}

struct ShellSettingsConfig: Equatable {
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

enum SettingsSection: String, CaseIterable, Identifiable {
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

func sampleSettingsData(displayMode: InventoryDisplayMode = .cards) -> ShellSettingsConfig {
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
        persistenceID: "keychain",
        title: "Keychain",
        detail: "Read metadata from macOS keychain entries generated by apps",
        enabled: true
      ),
      ScanSourceRow(
        persistenceID: "shell-profiles",
        title: "Shell profiles",
        detail: "Parse ~/.zshrc and ~/.bashrc for export statements",
        enabled: true
      ),
      ScanSourceRow(
        persistenceID: "environment-variables",
        title: "Environment variables",
        detail: "Enumerate non-secret environment values with credential-like names",
        enabled: false
      ),
      ScanSourceRow(
        persistenceID: "config-files",
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
