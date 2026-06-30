import KeydexCore

public protocol MetadataStore: Sendable {
  func listCredentials() async throws -> [CredentialRecord]
}

public struct EmptyMetadataStore: MetadataStore {
  public init() {}

  public func listCredentials() async throws -> [CredentialRecord] {
    []
  }
}
