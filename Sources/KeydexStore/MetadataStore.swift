import KeydexCore

public protocol MetadataStore: Sendable {
  func listCredentials() async throws -> [CredentialRecord]
  func ignoredCredentials() async throws -> Set<CredentialRef>
}

public struct EmptyMetadataStore: MetadataStore {
  public init() {}

  public func listCredentials() async throws -> [CredentialRecord] {
    []
  }

  public func ignoredCredentials() async throws -> Set<CredentialRef> {
    []
  }
}
