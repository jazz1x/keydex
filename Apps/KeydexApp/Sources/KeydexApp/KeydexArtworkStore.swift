import Foundation

struct CredentialArtworkOverride: Codable, Equatable {
  let credentialID: String
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
  let overrides: [CredentialRow.ID: CredentialArtworkOverride]
  let issueMessage: String?
}

enum CredentialArtworkStoreError: LocalizedError {
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
  private let fileManager: FileManager
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  var rootURL: URL {
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
        [CredentialRow.ID: CredentialArtworkOverride].self,
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
    credentialID: CredentialRow.ID,
    existingOverrides: [CredentialRow.ID: CredentialArtworkOverride]
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
    for credentialID: CredentialRow.ID,
    existingOverrides: [CredentialRow.ID: CredentialArtworkOverride]
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

  private func safeFileStem(for credentialID: CredentialRow.ID) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let scalars = credentialID.unicodeScalars.map { scalar in
      allowed.contains(scalar) ? Character(scalar) : "-"
    }
    let stem = String(scalars)
      .replacingOccurrences(of: "--", with: "-")
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return stem.isEmpty ? "credential-artwork" : stem
  }

  private func writeManifest(_ overrides: [CredentialRow.ID: CredentialArtworkOverride]) throws {
    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    let data = try encoder.encode(overrides)
    try data.write(to: manifestURL, options: [.atomic])
  }
}
