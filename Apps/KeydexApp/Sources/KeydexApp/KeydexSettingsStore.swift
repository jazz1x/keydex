import Foundation

struct ShellSettingsLoadState {
  let config: ShellSettingsConfig
  let issueMessage: String?
}

enum ShellSettingsStoreError: LocalizedError, Equatable {
  case fileOperation(String)

  var errorDescription: String? {
    switch self {
    case .fileOperation(let message):
      message
    }
  }
}

struct ShellSettingsStore {
  private let rootDirectoryURL: URL
  private let fileManager: FileManager
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  init(fileManager: FileManager = .default, rootURL: URL? = nil) {
    self.fileManager = fileManager
    rootDirectoryURL = rootURL ?? Self.defaultRootURL(fileManager: fileManager)
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  private static func defaultRootURL(fileManager: FileManager) -> URL {
    let rootURL: URL
    if let rawRoot = ProcessInfo.processInfo.environment["KEYDEX_APP_SETTINGS_ROOT"] {
      if rawRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        preconditionFailure(
          "Unsupported KEYDEX_APP_SETTINGS_ROOT value: expected a non-empty path."
        )
      }

      rootURL = URL(fileURLWithPath: rawRoot, isDirectory: true)
    } else {
      rootURL = fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Application Support", isDirectory: true)
        .appendingPathComponent("Keydex", isDirectory: true)
        .appendingPathComponent("Settings", isDirectory: true)
    }

    return rootURL
  }

  func load(defaults: ShellSettingsConfig) -> ShellSettingsLoadState {
    let manifestURL = manifestURL
    if !fileManager.fileExists(atPath: manifestURL.path) {
      return ShellSettingsLoadState(config: defaults, issueMessage: nil)
    }

    do {
      let data = try Data(contentsOf: manifestURL)
      let document = try decoder.decode(ShellSettingsDocument.self, from: data)
      return ShellSettingsLoadState(
        config: document.config(applyingTo: defaults),
        issueMessage: nil
      )
    } catch {
      return ShellSettingsLoadState(
        config: defaults,
        issueMessage: "Settings could not be read. Default settings are still available."
      )
    }
  }

  func save(_ config: ShellSettingsConfig) -> Result<Void, ShellSettingsStoreError> {
    do {
      try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
      let data = try encoder.encode(ShellSettingsDocument(config: config))
      try data.write(to: manifestURL, options: [.atomic])
      return .success(())
    } catch {
      return .failure(.fileOperation(error.localizedDescription))
    }
  }

  private var rootURL: URL {
    rootDirectoryURL
  }

  private var manifestURL: URL {
    rootURL.appendingPathComponent("settings.json", isDirectory: false)
  }
}

private struct ShellSettingsDocument: Codable, Equatable {
  let keychainAccess: Bool
  let requestPrompt: Bool
  let displayMode: InventoryDisplayMode
  let keychainReferences: [EditableSettingsRow]
  let scanSourceEnabledByID: [String: Bool]
  let legacyScanSourceEnabledStates: [Bool]?
  let scanPaths: [EditableSettingsRow]
  let tags: [CredentialTagRow]
  let expiryReminderPolicy: ExpiryReminderPolicy?
  let ignoredSources: [EditableSettingsRow]
  let unmanagedSources: [EditableSettingsRow]

  init(config: ShellSettingsConfig) {
    keychainAccess = config.keychainAccess
    requestPrompt = config.requestPrompt
    displayMode = config.displayMode
    keychainReferences = config.keychainReferences
    var scanSourceEnabledByID: [String: Bool] = [:]
    for source in config.scanSources {
      scanSourceEnabledByID[source.persistenceID] = source.enabled
    }
    self.scanSourceEnabledByID = scanSourceEnabledByID
    legacyScanSourceEnabledStates = nil
    scanPaths = config.scanPaths
    tags = config.tags
    expiryReminderPolicy = config.expiryReminderPolicy
    ignoredSources = config.ignoredSources
    unmanagedSources = config.unmanagedSources
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    keychainAccess = try container.decode(Bool.self, forKey: .keychainAccess)
    requestPrompt = try container.decode(Bool.self, forKey: .requestPrompt)
    displayMode = try container.decode(InventoryDisplayMode.self, forKey: .displayMode)
    keychainReferences = try container.decode(
      [EditableSettingsRow].self,
      forKey: .keychainReferences
    )

    if let scanSourceEnabledByID = try container.decodeIfPresent(
      [String: Bool].self,
      forKey: .scanSourceEnabledByID
    ) {
      self.scanSourceEnabledByID = scanSourceEnabledByID
      legacyScanSourceEnabledStates = nil
    } else {
      let legacyScanSources = try container.decode(
        [LegacyScanSourceDocument].self,
        forKey: .scanSources
      )
      scanSourceEnabledByID = [:]
      legacyScanSourceEnabledStates = legacyScanSources.map(\.enabled)
    }

    scanPaths = try container.decode([EditableSettingsRow].self, forKey: .scanPaths)
    tags = try container.decode([CredentialTagRow].self, forKey: .tags)
    expiryReminderPolicy = try container.decodeIfPresent(
      ExpiryReminderPolicy.self,
      forKey: .expiryReminderPolicy
    )
    ignoredSources = try container.decode([EditableSettingsRow].self, forKey: .ignoredSources)
    unmanagedSources = try container.decode([EditableSettingsRow].self, forKey: .unmanagedSources)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(keychainAccess, forKey: .keychainAccess)
    try container.encode(requestPrompt, forKey: .requestPrompt)
    try container.encode(displayMode, forKey: .displayMode)
    try container.encode(keychainReferences, forKey: .keychainReferences)
    try container.encode(scanSourceEnabledByID, forKey: .scanSourceEnabledByID)
    try container.encode(scanPaths, forKey: .scanPaths)
    try container.encode(tags, forKey: .tags)
    try container.encodeIfPresent(expiryReminderPolicy, forKey: .expiryReminderPolicy)
    try container.encode(ignoredSources, forKey: .ignoredSources)
    try container.encode(unmanagedSources, forKey: .unmanagedSources)
  }

  func config(applyingTo defaults: ShellSettingsConfig) -> ShellSettingsConfig {
    var config = defaults
    config.keychainAccess = keychainAccess
    config.requestPrompt = requestPrompt
    config.displayMode = displayMode
    config.keychainReferences = keychainReferences
    config.scanSources = defaults.scanSources.enumerated().map { index, source in
      var source = source
      if let enabled = scanSourceEnabledByID[source.persistenceID] {
        source.enabled = enabled
      } else if let legacyScanSourceEnabledStates,
        legacyScanSourceEnabledStates.indices.contains(index)
      {
        source.enabled = legacyScanSourceEnabledStates[index]
      }
      return source
    }
    config.scanPaths = scanPaths
    config.tags = tags
    if let expiryReminderPolicy {
      config.expiryReminderPolicy = expiryReminderPolicy
    }
    config.ignoredSources = ignoredSources
    config.unmanagedSources = unmanagedSources
    return config
  }

  private enum CodingKeys: String, CodingKey {
    case keychainAccess
    case requestPrompt
    case displayMode
    case keychainReferences
    case scanSourceEnabledByID
    case scanSources
    case scanPaths
    case tags
    case expiryReminderPolicy
    case ignoredSources
    case unmanagedSources
  }
}

private struct LegacyScanSourceDocument: Decodable, Equatable {
  let enabled: Bool
}
