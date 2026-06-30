import KeydexCore

public struct ShellProfile: Equatable, Sendable {
  public let path: NonEmptyText
  public let contents: String

  public init(path: NonEmptyText, contents: String) {
    self.path = path
    self.contents = contents
  }
}

public struct ShellProfileScanner: Sendable {
  public init() {}

  public func observations(from profiles: [ShellProfile]) throws -> [CredentialObservation] {
    var observations: [CredentialObservation] = []

    for profile in profiles {
      for line in profile.contents.split(separator: "\n", omittingEmptySubsequences: false) {
        if let name = Self.assignmentName(from: String(line)),
          let serviceName = CredentialNameClassifier.serviceName(from: name)
        {
          let ref = try CredentialRef.parse(service: serviceName, account: name)
          observations.append(
            CredentialObservation(
              ref: ref,
              state: .plaintextFallback,
              location: .shellProfile(path: profile.path)
            )
          )
        }
      }
    }

    return observations
  }

  private static func assignmentName(from line: String) -> String? {
    var trimmed = line.trimmingCharacters(in: .whitespaces)

    if trimmed.isEmpty || trimmed.hasPrefix("#") {
      return nil
    }

    if trimmed.hasPrefix("export ") {
      trimmed.removeFirst("export ".count)
      trimmed = trimmed.trimmingCharacters(in: .whitespaces)
    }

    let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
    if parts.count != 2 {
      return nil
    }

    let name = parts[0].trimmingCharacters(in: .whitespaces)
    let value = parts[1].trimmingCharacters(in: .whitespaces)

    if name.isEmpty || value.isEmpty || name.contains(" ") {
      return nil
    }

    return name
  }
}
