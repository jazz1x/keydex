import Foundation
import KeydexCore
import KeydexSources
import KeydexStore

public enum LocalInventorySourceID {
  public static let keychain = "keychain"
  public static let shellProfiles = "shell-profiles"
  public static let environmentVariables = "environment-variables"
  public static let configFiles = "config-files"
}

public struct LocalInventoryGraphRequest: Sendable {
  public let metadataURL: URL?
  public let enabledSourceIDs: Set<String>
  public let scanPathValues: [String]
  public let keychainReferenceValues: [String]
  public let ignoredSourceValues: Set<String>
  public let unmanagedSourceValues: Set<String>
  public let environment: [String: String]
  public let keychainObservations: [CredentialObservation]
  public let reconcilesKeychainReferences: Bool
  public let currentDate: Date

  public init(
    metadataURL: URL? = nil,
    enabledSourceIDs: Set<String> = [],
    scanPathValues: [String] = [],
    keychainReferenceValues: [String] = [],
    ignoredSourceValues: Set<String> = [],
    unmanagedSourceValues: Set<String> = [],
    environment: [String: String] = [:],
    keychainObservations: [CredentialObservation] = [],
    reconcilesKeychainReferences: Bool = false,
    currentDate: Date = Date()
  ) {
    self.metadataURL = metadataURL
    self.enabledSourceIDs = enabledSourceIDs
    self.scanPathValues = scanPathValues
    self.keychainReferenceValues = keychainReferenceValues
    self.ignoredSourceValues = ignoredSourceValues
    self.unmanagedSourceValues = unmanagedSourceValues
    self.environment = environment
    self.keychainObservations = keychainObservations
    self.reconcilesKeychainReferences = reconcilesKeychainReferences
    self.currentDate = currentDate
  }
}

public struct LocalInventoryGraphBuilder: Sendable {
  public init() {}

  public func graph(for request: LocalInventoryGraphRequest) async throws -> InventoryGraph {
    let metadataRecords = try await metadataRecords(for: request)
    let keychainRecords = try configuredKeychainRecords(for: request)
    let observations = try sourceObservations(for: request)
    let records = metadataRecords + keychainRecords

    if request.reconcilesKeychainReferences {
      return CredentialInventoryReconciler().graph(
        metadataRecords: records,
        keychainObservations: request.keychainObservations,
        additionalObservations: observations
      )
    }

    return InventoryGraph(
      records: records,
      observations: request.keychainObservations + observations
    )
  }

  private func metadataRecords(
    for request: LocalInventoryGraphRequest
  ) async throws -> [CredentialRecord] {
    guard let metadataURL = request.metadataURL else {
      return try await EmptyMetadataStore().listCredentials()
    }

    return try await FileMetadataStore(
      url: metadataURL,
      currentDate: request.currentDate
    )
    .listCredentials()
  }

  private func configuredKeychainRecords(
    for request: LocalInventoryGraphRequest
  ) throws -> [CredentialRecord] {
    guard request.enabledSourceIDs.contains(LocalInventorySourceID.keychain) else {
      return []
    }

    return try activeValues(
      request.keychainReferenceValues,
      suppressedBy: request.suppressedSourceValues
    ).map { rawReference in
      let ref = try Self.keychainReference(from: rawReference)
      return CredentialRecord(
        ref: ref,
        state: .missingKeychainItem,
        locations: [
          .keychain(service: ref.service, account: ref.account)
        ]
      )
    }
  }

  private func sourceObservations(
    for request: LocalInventoryGraphRequest
  ) throws -> [CredentialObservation] {
    var observations: [CredentialObservation] = []

    if request.enabledSourceIDs.contains(LocalInventorySourceID.environmentVariables) {
      observations += try EnvironmentScanner().observations(from: request.environment)
    }

    let paths = activeValues(request.scanPathValues, suppressedBy: request.suppressedSourceValues)
    if request.enabledSourceIDs.contains(LocalInventorySourceID.shellProfiles) {
      observations += try ShellProfileScanner().observations(
        from: try shellProfiles(from: paths)
      )
    }

    if request.enabledSourceIDs.contains(LocalInventorySourceID.configFiles) {
      observations += try ConfigFileScanner().observations(
        from: try configFiles(from: paths)
      )
    }

    return observations
  }

  private func shellProfiles(from pathValues: [String]) throws -> [ShellProfile] {
    try pathValues
      .filter(Self.isShellProfilePath)
      .map { pathValue in
        let path = expandedPath(pathValue)
        return ShellProfile(
          path: try NonEmptyText.parse(path, field: "path"),
          contents: try Self.contentsOfSourcePath(path)
        )
      }
  }

  private func configFiles(from pathValues: [String]) throws -> [ConfigFile] {
    try pathValues
      .filter { !Self.isShellProfilePath($0) }
      .map { pathValue in
        let path = expandedPath(pathValue)
        return ConfigFile(
          path: try NonEmptyText.parse(path, field: "path"),
          contents: try Self.contentsOfSourcePath(path)
        )
      }
  }

  private func activeValues(
    _ values: [String],
    suppressedBy suppressedValues: Set<String>
  ) -> [String] {
    values
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .filter { value in
        let expanded = expandedPath(value)
        return !suppressedValues.contains(value) && !suppressedValues.contains(expanded)
      }
  }

  private func expandedPath(_ value: String) -> String {
    (value as NSString).expandingTildeInPath
  }

  private static func keychainReference(from rawValue: String) throws -> CredentialRef {
    let parts = rawValue.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else {
      throw LocalInventoryRuntimeError.invalidKeychainReference(rawValue)
    }

    return try CredentialRef.parse(
      service: String(parts[0]),
      account: String(parts[1])
    )
  }

  private static func isShellProfilePath(_ pathValue: String) -> Bool {
    let lastPathComponent = URL(fileURLWithPath: pathValue).lastPathComponent
    return [
      ".bash_profile",
      ".bashrc",
      ".profile",
      ".zprofile",
      ".zshenv",
      ".zshrc",
    ].contains(lastPathComponent)
  }

  private static func contentsOfSourcePath(_ path: String) throws -> String {
    do {
      return try String(contentsOfFile: path, encoding: .utf8)
    } catch {
      throw LocalInventoryRuntimeError.sourcePathUnreadable(path)
    }
  }
}

extension LocalInventoryGraphRequest {
  fileprivate var suppressedSourceValues: Set<String> {
    ignoredSourceValues.union(unmanagedSourceValues)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .reduce(into: Set<String>()) { values, value in
        values.insert(value)
        values.insert((value as NSString).expandingTildeInPath)
      }
  }
}

public enum LocalInventoryRuntimeError: Error, Equatable, LocalizedError {
  case invalidKeychainReference(String)
  case sourcePathUnreadable(String)

  public var errorDescription: String? {
    switch self {
    case .invalidKeychainReference(let rawValue):
      "invalid keychain reference: \(rawValue). Expected service/account"
    case .sourcePathUnreadable(let path):
      "source path could not be read: \(path)"
    }
  }
}
