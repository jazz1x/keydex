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

public struct CredentialExpiry: Equatable, Sendable {
  public let expiresAt: Date
  public let notifyBeforeDays: Int?

  public init(expiresAt: Date, notifyBeforeDays: Int? = nil) {
    self.expiresAt = expiresAt
    self.notifyBeforeDays = notifyBeforeDays
  }

  public var notifyAt: Date? {
    guard let notifyBeforeDays else {
      return nil
    }

    return expiresAt.addingTimeInterval(TimeInterval(-notifyBeforeDays * 24 * 60 * 60))
  }
}

public struct CredentialRecord: Equatable, Sendable {
  public let ref: CredentialRef
  public let state: CredentialState
  public let locations: [CredentialLocation]
  public let expiry: CredentialExpiry?

  public init(
    ref: CredentialRef,
    state: CredentialState,
    locations: [CredentialLocation],
    expiry: CredentialExpiry? = nil
  ) {
    self.ref = ref
    self.state = state
    self.locations = locations
    self.expiry = expiry
  }
}

public enum CredentialExpiryReminderStatus: String, Equatable, Sendable {
  case scheduled
  case due
  case expired
}

public struct CredentialExpiryReminder: Equatable, Sendable {
  public let credential: CredentialRef
  public let expiresAt: Date
  public let notifyAt: Date
  public let notifyBeforeDays: Int
  public let status: CredentialExpiryReminderStatus

  public init(
    credential: CredentialRef,
    expiresAt: Date,
    notifyAt: Date,
    notifyBeforeDays: Int,
    status: CredentialExpiryReminderStatus
  ) {
    self.credential = credential
    self.expiresAt = expiresAt
    self.notifyAt = notifyAt
    self.notifyBeforeDays = notifyBeforeDays
    self.status = status
  }
}

public struct CredentialExpiryReminderPlanner: Sendable {
  public init() {}

  public func reminders(
    from records: [CredentialRecord],
    currentDate: Date = Date()
  ) -> [CredentialExpiryReminder] {
    records.compactMap { record in
      guard let expiry = record.expiry,
        let notifyBeforeDays = expiry.notifyBeforeDays,
        let notifyAt = expiry.notifyAt
      else {
        return nil
      }

      return CredentialExpiryReminder(
        credential: record.ref,
        expiresAt: expiry.expiresAt,
        notifyAt: notifyAt,
        notifyBeforeDays: notifyBeforeDays,
        status: reminderStatus(
          expiresAt: expiry.expiresAt,
          notifyAt: notifyAt,
          currentDate: currentDate
        )
      )
    }
    .sorted(by: reminderSort)
  }

  private func reminderStatus(
    expiresAt: Date,
    notifyAt: Date,
    currentDate: Date
  ) -> CredentialExpiryReminderStatus {
    if currentDate >= expiresAt {
      return .expired
    }

    if currentDate >= notifyAt {
      return .due
    }

    return .scheduled
  }

  private func reminderSort(
    _ left: CredentialExpiryReminder,
    _ right: CredentialExpiryReminder
  ) -> Bool {
    if left.status != right.status {
      return statusOrder(left.status) < statusOrder(right.status)
    }

    if left.notifyAt != right.notifyAt {
      return left.notifyAt < right.notifyAt
    }

    if left.credential.service.value == right.credential.service.value {
      return left.credential.account.value < right.credential.account.value
    }

    return left.credential.service.value < right.credential.service.value
  }

  private func statusOrder(_ status: CredentialExpiryReminderStatus) -> Int {
    switch status {
    case .expired:
      0
    case .due:
      1
    case .scheduled:
      2
    }
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
