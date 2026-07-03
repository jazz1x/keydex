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
    fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)
      .appendingPathComponent("Keydex", isDirectory: true)
      .appendingPathComponent("Settings", isDirectory: true)
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
  let scanPaths: [EditableSettingsRow]
  let tags: [CredentialTagRow]
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
    scanPaths = config.scanPaths
    tags = config.tags
    ignoredSources = config.ignoredSources
    unmanagedSources = config.unmanagedSources
  }

  func config(applyingTo defaults: ShellSettingsConfig) -> ShellSettingsConfig {
    var config = defaults
    config.keychainAccess = keychainAccess
    config.requestPrompt = requestPrompt
    config.displayMode = displayMode
    config.keychainReferences = keychainReferences
    config.scanSources = defaults.scanSources.map { source in
      var source = source
      if let enabled = scanSourceEnabledByID[source.persistenceID] {
        source.enabled = enabled
      }
      return source
    }
    config.scanPaths = scanPaths
    config.tags = tags
    config.ignoredSources = ignoredSources
    config.unmanagedSources = unmanagedSources
    return config
  }
}
