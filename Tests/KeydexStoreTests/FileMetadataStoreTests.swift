import Foundation
import KeydexCore
import KeydexStore
import Testing

@Test
func fileMetadataStoreLoadsCredentialRecordsWithoutSecretValues() async throws {
  let url = try writeMetadataFixture(
    """
    {
      "records": [
        {
          "service": "openai",
          "account": "jongyun",
          "state": "plaintext-fallback",
          "locations": [
            { "kind": "environment", "name": "OPENAI_API_KEY" },
            { "kind": "shell-profile", "path": "~/.zshrc" }
          ]
        }
      ]
    }
    """
  )

  let records = try await FileMetadataStore(url: url).listCredentials()
  let record = try #require(records.first)
  let envName = try NonEmptyText.parse("OPENAI_API_KEY", field: "name")
  let shellPath = try NonEmptyText.parse("~/.zshrc", field: "path")
  let expectedLocations: [CredentialLocation] = [
    .environment(name: envName),
    .shellProfile(path: shellPath),
  ]

  #expect(records.count == 1)
  #expect(record.ref.service.value == "openai")
  #expect(record.ref.account.value == "jongyun")
  #expect(record.state == .plaintextFallback)
  #expect(record.locations == expectedLocations)
  #expect(String(describing: records).contains("sk-test-secret") == false)
}

@Test
func fileMetadataStoreLoadsIgnoredCredentialRefs() async throws {
  let url = try writeMetadataFixture(
    """
    {
      "records": [],
      "ignoredCredentials": [
        { "service": "bitbucket", "account": "jongyun" }
      ]
    }
    """
  )

  let ignored = try await FileMetadataStore(url: url).ignoredCredentials()
  let expectedRef = try CredentialRef.parse(service: "bitbucket", account: "jongyun")

  #expect(ignored == [expectedRef])
}

@Test
func fileMetadataStoreRejectsInvalidState() async throws {
  let url = try writeMetadataFixture(
    """
    {
      "records": [
        {
          "service": "openai",
          "account": "jongyun",
          "state": "healthy-ish",
          "locations": []
        }
      ]
    }
    """
  )

  await #expect(throws: MetadataStoreError.invalidState("healthy-ish")) {
    try await FileMetadataStore(url: url).listCredentials()
  }
}

@Test
func fileMetadataStoreRejectsMissingLocationFields() async throws {
  let url = try writeMetadataFixture(
    """
    {
      "records": [
        {
          "service": "openai",
          "account": "jongyun",
          "state": "registered",
          "locations": [
            { "kind": "keychain", "service": "openai" }
          ]
        }
      ]
    }
    """
  )

  await #expect(
    throws: MetadataStoreError.missingLocationField(kind: "keychain", field: "account")
  ) {
    try await FileMetadataStore(url: url).listCredentials()
  }
}

private func writeMetadataFixture(_ contents: String) throws -> URL {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

  let url = directory.appendingPathComponent("metadata.json")
  try contents.write(to: url, atomically: true, encoding: .utf8)
  return url
}
