import Foundation
import KeydexCore

public struct FileMetadataStore: MetadataStore {
  public let url: URL

  public init(url: URL) {
    self.url = url
  }

  public func listCredentials() async throws -> [CredentialRecord] {
    let data = try Data(contentsOf: url)
    let document = try JSONDecoder().decode(MetadataDocument.self, from: data)

    return try document.records.map { record in
      CredentialRecord(
        ref: try CredentialRef.parse(service: record.service, account: record.account),
        state: try record.credentialState(),
        locations: try record.locations.map { try $0.credentialLocation() }
      )
    }
  }
}

private struct MetadataDocument: Decodable {
  let records: [MetadataRecord]
}

private struct MetadataRecord: Decodable {
  let service: String
  let account: String
  let state: String
  let locations: [MetadataLocation]

  func credentialState() throws -> CredentialState {
    guard let credentialState = CredentialState(rawValue: state) else {
      throw MetadataStoreError.invalidState(state)
    }

    return credentialState
  }
}

private struct MetadataLocation: Decodable {
  let kind: String
  let service: String?
  let account: String?
  let name: String?
  let path: String?

  func credentialLocation() throws -> CredentialLocation {
    switch kind {
    case "keychain":
      return .keychain(
        service: try requireText(service, field: "service"),
        account: try requireText(account, field: "account")
      )
    case "environment":
      return .environment(name: try requireText(name, field: "name"))
    case "shell-profile":
      return .shellProfile(path: try requireText(path, field: "path"))
    case "config-file":
      return .configFile(path: try requireText(path, field: "path"))
    default:
      throw MetadataStoreError.invalidLocationKind(kind)
    }
  }

  private func requireText(_ value: String?, field: String) throws -> NonEmptyText {
    guard let value else {
      throw MetadataStoreError.missingLocationField(kind: kind, field: field)
    }

    return try NonEmptyText.parse(value, field: field)
  }
}

public enum MetadataStoreError: Error, Equatable, LocalizedError {
  case invalidState(String)
  case invalidLocationKind(String)
  case missingLocationField(kind: String, field: String)

  public var errorDescription: String? {
    switch self {
    case .invalidState(let state):
      "invalid credential state: \(state)"
    case .invalidLocationKind(let kind):
      "invalid credential location kind: \(kind)"
    case .missingLocationField(let kind, let field):
      "\(kind) location is missing \(field)"
    }
  }
}
