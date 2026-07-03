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
      let config = try decoder.decode(ShellSettingsConfig.self, from: data)
      return ShellSettingsLoadState(config: config, issueMessage: nil)
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
      let data = try encoder.encode(config)
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
