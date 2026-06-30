public enum DoctorSeverity: String, Equatable, Sendable {
  case info
  case warning
  case error
}

public struct DoctorIssue: Equatable, Sendable {
  public let severity: DoctorSeverity
  public let state: CredentialState
  public let message: String
  public let action: String

  public init(severity: DoctorSeverity, state: CredentialState, message: String, action: String) {
    self.severity = severity
    self.state = state
    self.message = message
    self.action = action
  }
}

public struct CredentialDoctor: Sendable {
  public init() {}

  public func inspect(_ records: [CredentialRecord]) -> [DoctorIssue] {
    records.flatMap { record in
      issue(for: record).map { [$0] } ?? []
    }
  }

  private func issue(for record: CredentialRecord) -> DoctorIssue? {
    switch record.state {
    case .registered:
      nil
    case .missingKeychainItem:
      DoctorIssue(
        severity: .error,
        state: record.state,
        message: "metadata points at a Keychain item that is missing",
        action: "register the real Keychain item or remove stale metadata"
      )
    case .plaintextFallback:
      DoctorIssue(
        severity: .warning,
        state: record.state,
        message: "credential can still be resolved from plaintext configuration",
        action: "migrate the value to Keychain and remove the plaintext fallback"
      )
    case .orphan:
      DoctorIssue(
        severity: .warning,
        state: record.state,
        message: "Keychain item exists without Keydex metadata",
        action: "register metadata or mark the item as intentionally unmanaged"
      )
    case .expiring:
      DoctorIssue(
        severity: .warning,
        state: record.state,
        message: "credential is nearing its expiry date",
        action: "rotate the credential before it expires"
      )
    case .expired:
      DoctorIssue(
        severity: .error,
        state: record.state,
        message: "credential is expired",
        action: "rotate or remove the credential"
      )
    case .duplicate:
      DoctorIssue(
        severity: .warning,
        state: record.state,
        message: "multiple entries appear to represent the same credential",
        action: "choose the authoritative item and remove the duplicate reference"
      )
    }
  }
}
