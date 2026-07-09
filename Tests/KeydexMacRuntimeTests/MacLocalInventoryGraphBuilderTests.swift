import KeydexCore
import KeydexKeychain
import KeydexMacRuntime
import KeydexRuntime
import Testing

@Test
func macLocalInventoryGraphBuilderReconcilesLiveKeychainReferences() async throws {
  let builder = MacLocalInventoryGraphBuilder {
    [
      try KeychainItemReference(service: "openai", account: "default"),
      try KeychainItemReference(service: "slack", account: "bot"),
    ]
  }

  let graph = try await builder.graph(
    for: LocalInventoryGraphRequest(
      enabledSourceIDs: [LocalInventorySourceID.keychain],
      keychainReferenceValues: ["openai/default"]
    )
  )

  let projections = graph.credentialProjections
  let openAI = try #require(projections.first { $0.ref.service.value == "openai" })
  let slack = try #require(projections.first { $0.ref.service.value == "slack" })

  #expect(openAI.states == [.registered])
  #expect(slack.states == [.orphan])
}

@Test
func macLocalInventoryGraphBuilderSkipsLiveKeychainWhenSourceDisabled() async throws {
  let builder = MacLocalInventoryGraphBuilder {
    throw MacRuntimeTestError.unexpectedKeychainScan
  }

  let graph = try await builder.graph(
    for: LocalInventoryGraphRequest(
      enabledSourceIDs: [],
      keychainReferenceValues: ["openai/default"]
    )
  )

  #expect(graph.credentialProjections.isEmpty)
}

private enum MacRuntimeTestError: Error {
  case unexpectedKeychainScan
}
