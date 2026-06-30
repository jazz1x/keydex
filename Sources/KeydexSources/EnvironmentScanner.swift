import KeydexCore

public struct EnvironmentScanner: Sendable {
  public init() {}

  public func observations(from environment: [String: String]) throws -> [CredentialObservation] {
    var observations: [CredentialObservation] = []

    for entry in environment.sorted(by: { $0.key < $1.key }) {
      if entry.value.isEmpty {
        continue
      }

      if let serviceName = CredentialNameClassifier.serviceName(from: entry.key) {
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
}
