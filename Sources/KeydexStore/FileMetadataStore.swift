import Foundation
import KeydexCore

public struct FileMetadataStore: MetadataStore {
  public let url: URL
  public let currentDate: Date

  public init(url: URL, currentDate: Date = Date()) {
    self.url = url
    self.currentDate = currentDate
  }

  public func listCredentials() async throws -> [CredentialRecord] {
    let document = try loadDocument()

    return try document.records.map { record in
      let expiry = try record.credentialExpiry()
      return CredentialRecord(
        ref: try CredentialRef.parse(service: record.service, account: record.account),
        state: try record.credentialState(currentDate: currentDate, expiry: expiry),
        locations: try record.locations.map { try $0.credentialLocation() },
        expiry: expiry
      )
    }
  }

  public func ignoredCredentials() async throws -> Set<CredentialRef> {
    let document = try loadDocument()
    return Set(try document.ignoredCredentials.map { try $0.credentialRef() })
  }

  private func loadDocument() throws -> MetadataDocument {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(MetadataDocument.self, from: data)
  }
}

private struct MetadataDocument: Decodable {
  let records: [MetadataRecord]
  let ignoredCredentials: [MetadataCredentialRef]

  private enum CodingKeys: String, CodingKey {
    case records
    case ignoredCredentials
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    records = try container.decode([MetadataRecord].self, forKey: .records)
    ignoredCredentials =
      try container.decodeIfPresent([MetadataCredentialRef].self, forKey: .ignoredCredentials) ?? []
  }
}

private struct MetadataRecord: Decodable {
  let service: String
  let account: String
  let state: String
  let expiresAt: String?
  let notifyBeforeDays: Int?
  let locations: [MetadataLocation]

  func credentialState(currentDate: Date, expiry: CredentialExpiry?) throws -> CredentialState {
    if let expiry {
      if expiry.expiresAt <= currentDate {
        return .expired
      }

      if expiry.expiresAt <= currentDate.addingTimeInterval(30 * 24 * 60 * 60) {
        return .expiring
      }
    }

    guard let credentialState = CredentialState(rawValue: state) else {
      throw MetadataStoreError.invalidState(state)
    }

    return credentialState
  }

  func credentialExpiry() throws -> CredentialExpiry? {
    guard let expiresAt else {
      if let notifyBeforeDays {
        throw MetadataStoreError.notificationRequiresExpiry(notifyBeforeDays)
      }

      return nil
    }

    let expiryDate = try Self.expiryDate(from: expiresAt)
    if let notifyBeforeDays, notifyBeforeDays < 0 {
      throw MetadataStoreError.invalidNotificationLeadDays(notifyBeforeDays)
    }

    return CredentialExpiry(expiresAt: expiryDate, notifyBeforeDays: notifyBeforeDays)
  }

  private static func expiryDate(from value: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    guard let date = formatter.date(from: value) else {
      throw MetadataStoreError.invalidExpiryDate(value)
    }

    return date
  }
}

private struct MetadataCredentialRef: Decodable {
  let service: String
  let account: String

  func credentialRef() throws -> CredentialRef {
    try CredentialRef.parse(service: service, account: account)
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
  case invalidExpiryDate(String)
  case invalidNotificationLeadDays(Int)
  case notificationRequiresExpiry(Int)
  case invalidLocationKind(String)
  case missingLocationField(kind: String, field: String)

  public var errorDescription: String? {
    switch self {
    case .invalidState(let state):
      "invalid credential state: \(state)"
    case .invalidExpiryDate(let value):
      "invalid credential expiry date: \(value)"
    case .invalidNotificationLeadDays(let value):
      "invalid credential notification lead days: \(value)"
    case .notificationRequiresExpiry(let value):
      "credential notification lead days require expiresAt: \(value)"
    case .invalidLocationKind(let kind):
      "invalid credential location kind: \(kind)"
    case .missingLocationField(let kind, let field):
      "\(kind) location is missing \(field)"
    }
  }
}
