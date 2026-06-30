struct CredentialNameClassifier {
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

  static func serviceName(from name: String) -> String? {
    let uppercasedName = name.uppercased()

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
