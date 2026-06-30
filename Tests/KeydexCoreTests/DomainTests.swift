import KeydexCore
import Testing

@Test
func nonEmptyTextTrimsInput() throws {
  let text = try NonEmptyText.parse("  openai  ", field: "service")

  #expect(text.value == "openai")
}

@Test
func nonEmptyTextRejectsBlankInput() {
  #expect(throws: KeydexError.emptyField("service")) {
    try NonEmptyText.parse("   ", field: "service")
  }
}

@Test
func credentialStateRawValuesAreStableCliLabels() {
  #expect(CredentialState.plaintextFallback.rawValue == "plaintext-fallback")
  #expect(CredentialState.missingKeychainItem.rawValue == "missing-keychain-item")
}

@Test
func inventoryGraphProjectsRecordsIntoNodesAndEdges() throws {
  let ref = try CredentialRef.parse(service: "openai", account: "jongyun")
  let service = try NonEmptyText.parse("openai", field: "service")
  let account = try NonEmptyText.parse("jongyun", field: "account")
  let envName = try NonEmptyText.parse("OPENAI_API_KEY", field: "name")
  let record = CredentialRecord(
    ref: ref,
    state: .plaintextFallback,
    locations: [
      .keychain(service: service, account: account),
      .environment(name: envName),
    ]
  )

  let graph = InventoryGraph(records: [record])
  let credentialNode = InventoryNode.credential(ref)

  #expect(graph.nodes.contains(credentialNode))
  #expect(graph.nodes.contains(.state(.plaintextFallback)))
  #expect(
    graph.edges.contains(
      InventoryEdge(from: credentialNode, to: .state(.plaintextFallback), kind: .hasState)
    )
  )
  #expect(
    graph.outgoingEdges(from: credentialNode).map(\.kind) == [
      .hasState,
      .storedIn,
      .observedIn,
    ]
  )
}
