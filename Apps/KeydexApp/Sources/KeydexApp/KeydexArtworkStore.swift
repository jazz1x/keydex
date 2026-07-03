import Foundation

typealias CredentialArtworkID = String

struct CredentialArtworkOverride: Codable, Equatable {
  let credentialID: CredentialArtworkID
  let fileName: String

  func fileURL(rootURL: URL) -> URL {
    rootURL.appendingPathComponent(safeFileName, isDirectory: false)
  }

  private var safeFileName: String {
    let lastPathComponent = URL(fileURLWithPath: fileName).lastPathComponent
    return lastPathComponent.isEmpty ? "credential-artwork" : lastPathComponent
  }
}

struct CredentialArtworkLoadState {
  let overrides: [CredentialArtworkID: CredentialArtworkOverride]
  let issueMessage: String?
}

enum CredentialArtworkStoreError: LocalizedError, Equatable {
  case unsupportedImageType(String)
  case fileOperation(String)

  var errorDescription: String? {
    switch self {
    case .unsupportedImageType(let pathExtension):
      "Unsupported artwork image type: \(pathExtension)"
    case .fileOperation(let message):
      message
    }
  }
}

struct CredentialArtworkStore {
  private let rootDirectoryURL: URL
  private let fileManager: FileManager
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  init(fileManager: FileManager = .default, rootURL: URL? = nil) {
    self.fileManager = fileManager
    rootDirectoryURL = rootURL ?? Self.defaultRootURL(fileManager: fileManager)
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  var rootURL: URL {
    rootDirectoryURL
  }

  private static func defaultRootURL(fileManager: FileManager) -> URL {
    fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)
      .appendingPathComponent("Keydex", isDirectory: true)
      .appendingPathComponent("Artwork", isDirectory: true)
  }

  func loadOverrides() -> CredentialArtworkLoadState {
    let manifestURL = manifestURL
    if !fileManager.fileExists(atPath: manifestURL.path) {
      return CredentialArtworkLoadState(overrides: [:], issueMessage: nil)
    }

    do {
      let data = try Data(contentsOf: manifestURL)
      let overrides = try decoder.decode(
        [CredentialArtworkID: CredentialArtworkOverride].self,
        from: data
      )
      return CredentialArtworkLoadState(overrides: overrides, issueMessage: nil)
    } catch {
      return CredentialArtworkLoadState(
        overrides: [:],
        issueMessage: "Custom artwork manifest could not be read. "
          + "Default artwork is still available."
      )
    }
  }

  func importArtwork(
    from sourceURL: URL,
    credentialID: CredentialArtworkID,
    existingOverrides: [CredentialArtworkID: CredentialArtworkOverride]
  ) -> Result<CredentialArtworkOverride, CredentialArtworkStoreError> {
    let pathExtension = normalizedPathExtension(for: sourceURL)
    guard supportedImageExtensions.contains(pathExtension) else {
      return .failure(.unsupportedImageType(pathExtension.isEmpty ? "<none>" : pathExtension))
    }

    let destinationURL =
      rootURL
      .appendingPathComponent(safeFileStem(for: credentialID), isDirectory: false)
      .appendingPathExtension(pathExtension)

    let didAccessSecurityScopedResource = sourceURL.startAccessingSecurityScopedResource()
    defer {
      if didAccessSecurityScopedResource {
        sourceURL.stopAccessingSecurityScopedResource()
      }
    }

    do {
      try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
      if sourceURL.standardizedFileURL != destinationURL.standardizedFileURL {
        if fileManager.fileExists(atPath: destinationURL.path) {
          try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
      }
      if let previousURL = existingOverrides[credentialID]?.fileURL(rootURL: rootURL)
        .standardizedFileURL,
        previousURL != destinationURL.standardizedFileURL,
        fileManager.fileExists(atPath: previousURL.path)
      {
        try fileManager.removeItem(at: previousURL)
      }

      let override = CredentialArtworkOverride(
        credentialID: credentialID,
        fileName: destinationURL.lastPathComponent
      )
      var nextOverrides = existingOverrides
      nextOverrides[credentialID] = override
      try writeManifest(nextOverrides)
      return .success(override)
    } catch {
      return .failure(.fileOperation(error.localizedDescription))
    }
  }

  func removeArtwork(
    for credentialID: CredentialArtworkID,
    existingOverrides: [CredentialArtworkID: CredentialArtworkOverride]
  ) -> Result<Void, CredentialArtworkStoreError> {
    do {
      var nextOverrides = existingOverrides
      if let existing = nextOverrides.removeValue(forKey: credentialID) {
        let existingURL = existing.fileURL(rootURL: rootURL)
        if fileManager.fileExists(atPath: existingURL.path) {
          try fileManager.removeItem(at: existingURL)
        }
      }

      try writeManifest(nextOverrides)
      return .success(())
    } catch {
      return .failure(.fileOperation(error.localizedDescription))
    }
  }

  private var manifestURL: URL {
    rootURL.appendingPathComponent("manifest.json", isDirectory: false)
  }

  private var supportedImageExtensions: Set<String> {
    ["png", "jpg", "jpeg", "heic", "tiff"]
  }

  private func normalizedPathExtension(for url: URL) -> String {
    url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private func safeFileStem(for credentialID: CredentialArtworkID) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let scalars = credentialID.unicodeScalars.map { scalar in
      allowed.contains(scalar) ? Character(scalar) : "-"
    }
    let readableStem = String(scalars)
      .split(separator: "-", omittingEmptySubsequences: true)
      .joined(separator: "-")
    let identitySuffix = hexEncodedCredentialID(credentialID)

    if readableStem.isEmpty {
      return identitySuffix.isEmpty ? "credential-artwork" : "credential-artwork-\(identitySuffix)"
    }
    return "\(readableStem)-\(identitySuffix)"
  }

  private func hexEncodedCredentialID(_ credentialID: CredentialArtworkID) -> String {
    credentialID.utf8.map { byte in
      let text = String(byte, radix: 16)
      return byte < 16 ? "0\(text)" : text
    }.joined()
  }

  private func writeManifest(_ overrides: [CredentialArtworkID: CredentialArtworkOverride]) throws {
    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    let data = try encoder.encode(overrides)
    try data.write(to: manifestURL, options: [.atomic])
  }
}
