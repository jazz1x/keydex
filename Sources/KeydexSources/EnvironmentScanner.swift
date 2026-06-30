import KeydexCore

public struct EnvironmentScanner: Sendable {
  private static let credentialSuffixes = [
    "ACCESS_KEY_ID",
    "CLIENT_SECRET",
    "SECRET_KEY",
    "ACCESS_TOKEN",
    "API_KEY",
    "PASSWORD",
    "SECRET",
    "TOKEN",
  ]

  public init() {}

  public func observations(from environment: [String: String]) throws -> [CredentialObservation] {
    var observations: [CredentialObservation] = []

    for entry in environment.sorted(by: { $0.key < $1.key }) {
      if entry.value.isEmpty {
        continue
      }

      if let serviceName = Self.serviceName(from: entry.key) {
        let ref = try CredentialRef.parse(service: serviceName, account: entry.key)
        let name = try NonEmptyText.parse(entry.key, field: "name")
        observations.append(
          CredentialObservation(
            ref: ref,
            state: .plaintextFallback,
            location: .environment(name: name)
          )
        )
      }
    }

    return observations
  }

  private static func serviceName(from variableName: String) -> String? {
    let uppercasedName = variableName.uppercased()

    for suffix in credentialSuffixes {
      let marker = "_\(suffix)"
      if uppercasedName.hasSuffix(marker) && uppercasedName.count > marker.count {
        let prefix = uppercasedName.dropLast(marker.count)
        return prefix.lowercased().replacingOccurrences(of: "_", with: "-")
      }
    }

    return nil
  }
}
