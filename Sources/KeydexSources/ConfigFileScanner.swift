import KeydexCore

public struct ConfigFile: Equatable, Sendable {
  public let path: NonEmptyText
  public let contents: String

  public init(path: NonEmptyText, contents: String) {
    self.path = path
    self.contents = contents
  }
}

public struct ConfigFileScanner: Sendable {
  public init() {}

  public func observations(from files: [ConfigFile]) throws -> [CredentialObservation] {
    var observations: [CredentialObservation] = []

    for file in files {
      for line in file.contents.split(separator: "\n", omittingEmptySubsequences: false) {
        if let name = Self.assignmentName(from: String(line)),
          let serviceName = CredentialNameClassifier.serviceName(from: name)
        {
          let ref = try CredentialRef.parse(service: serviceName, account: name)
          observations.append(
            CredentialObservation(
              ref: ref,
              state: .plaintextFallback,
              location: .configFile(path: file.path)
            )
          )
        }
      }
    }

    return observations
  }

  private static func assignmentName(from line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    if trimmed.isEmpty || trimmed.hasPrefix("#") {
      return nil
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
