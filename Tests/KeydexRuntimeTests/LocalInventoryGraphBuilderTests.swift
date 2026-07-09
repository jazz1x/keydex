import Foundation
import KeydexCore
import KeydexRuntime
import Testing

@Test
func localInventoryGraphBuilderScansEnabledShellAndConfigPaths() async throws {
  let rootURL = temporaryRuntimeRoot()
  let shellURL = rootURL.appendingPathComponent(".zshrc", isDirectory: false)
  let configURL = rootURL.appendingPathComponent("service.env", isDirectory: false)
  try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
  try "export OPENAI_API_KEY=sk-test-secret\n".write(
    to: shellURL,
    atomically: true,
    encoding: .utf8
  )
  try "SLACK_TOKEN=xoxb-test-secret\n".write(
    to: configURL,
    atomically: true,
    encoding: .utf8
  )

  let graph = try await LocalInventoryGraphBuilder().graph(
    for: LocalInventoryGraphRequest(
      enabledSourceIDs: [
        LocalInventorySourceID.shellProfiles,
        LocalInventorySourceID.configFiles,
      ],
      scanPathValues: [
        shellURL.path,
        configURL.path,
      ]
    )
  )

  let projections = graph.credentialProjections

  #expect(projections.map(\.ref.service.value) == ["openai", "slack"])
  #expect(projections.flatMap(\.states) == [.plaintextFallback, .plaintextFallback])
  #expect(String(describing: graph).contains("sk-test-secret") == false)
  #expect(String(describing: graph).contains("xoxb-test-secret") == false)
}

@Test
func localInventoryGraphBuilderTreatsConfiguredKeychainReferenceAsMetadata() async throws {
  let graph = try await LocalInventoryGraphBuilder().graph(
    for: LocalInventoryGraphRequest(
      enabledSourceIDs: [LocalInventorySourceID.keychain],
      keychainReferenceValues: [
        "openai/default",
        "ignored/service",
      ],
      ignoredSourceValues: ["ignored/service"],
      reconcilesKeychainReferences: true
    )
  )
  let projection = try #require(graph.credentialProjections.first)
  let issue = try #require(CredentialDoctor().inspect(graph).first)

  #expect(graph.credentialProjections.count == 1)
  #expect(projection.ref.service.value == "openai")
  #expect(projection.ref.account.value == "default")
  #expect(projection.states == [.missingKeychainItem])
  #expect(issue.action == "register the real Keychain item or remove stale metadata")
}

@Test
func localInventoryGraphBuilderKeepsMetadataStateWithoutKeychainReconciliation() async throws {
  let rootURL = temporaryRuntimeRoot()
  let metadataURL = rootURL.appendingPathComponent("metadata.json", isDirectory: false)
  try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
  try """
  {
    "records" : [
      {
        "service" : "openai",
        "account" : "default",
        "state" : "registered",
        "locations" : [
          {
            "kind" : "keychain",
            "service" : "openai",
            "account" : "default"
          }
        ]
      }
    ]
  }
  """.write(to: metadataURL, atomically: true, encoding: .utf8)

  let graph = try await LocalInventoryGraphBuilder().graph(
    for: LocalInventoryGraphRequest(metadataURL: metadataURL)
  )
  let projection = try #require(graph.credentialProjections.first)

  #expect(projection.states == [.registered])
  #expect(CredentialDoctor().inspect(graph).isEmpty)
}

private func temporaryRuntimeRoot() -> URL {
  FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
}
