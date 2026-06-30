import Foundation

public struct NonEmptyText: Equatable, Hashable, Sendable, CustomStringConvertible {
  public let value: String

  private init(_ value: String) {
    self.value = value
  }

  public var description: String {
    value
  }

  public static func parse(_ rawValue: String, field: String) throws -> Self {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw KeydexError.emptyField(field)
    }

    return Self(trimmed)
  }
}

public struct CredentialRef: Equatable, Hashable, Sendable {
  public let service: NonEmptyText
  public let account: NonEmptyText

  private init(service: NonEmptyText, account: NonEmptyText) {
    self.service = service
    self.account = account
  }

  public static func parse(service: String, account: String) throws -> Self {
    Self(
      service: try .parse(service, field: "service"),
      account: try .parse(account, field: "account")
    )
  }
}

public enum CredentialLocation: Equatable, Hashable, Sendable {
  case keychain(service: NonEmptyText, account: NonEmptyText)
  case environment(name: NonEmptyText)
  case shellProfile(path: NonEmptyText)
  case configFile(path: NonEmptyText)
}

public enum CredentialState: String, CaseIterable, Equatable, Hashable, Sendable {
  case registered
  case missingKeychainItem = "missing-keychain-item"
  case plaintextFallback = "plaintext-fallback"
  case orphan
  case expiring
  case expired
  case duplicate
}

public struct CredentialObservation: Equatable, Hashable, Sendable {
  public let ref: CredentialRef
  public let state: CredentialState
  public let location: CredentialLocation

  public init(ref: CredentialRef, state: CredentialState, location: CredentialLocation) {
    self.ref = ref
    self.state = state
    self.location = location
  }
}

public struct CredentialRecord: Equatable, Sendable {
  public let ref: CredentialRef
  public let state: CredentialState
  public let locations: [CredentialLocation]

  public init(ref: CredentialRef, state: CredentialState, locations: [CredentialLocation]) {
    self.ref = ref
    self.state = state
    self.locations = locations
  }
}

public enum KeydexError: Error, Equatable, LocalizedError {
  case emptyField(String)
  case invalidKeychainAttribute(String)
  case invalidKeychainQueryResult(String)
  case keychainQueryFailed(Int32)
  case unsupportedOperation(String)

  public var errorDescription: String? {
    switch self {
    case .emptyField(let field):
      "\(field) must not be empty"
    case .invalidKeychainAttribute(let attribute):
      "Keychain item is missing valid \(attribute)"
    case .invalidKeychainQueryResult(let description):
      "Keychain query returned invalid \(description)"
    case .keychainQueryFailed(let status):
      "Keychain query failed with OSStatus \(status)"
    case .unsupportedOperation(let operation):
      "\(operation) is not implemented yet"
    }
  }
}
