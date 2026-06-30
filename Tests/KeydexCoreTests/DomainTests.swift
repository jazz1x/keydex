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

@Test
func inventoryGraphProjectsObservationsIntoNodesAndEdges() throws {
  let ref = try CredentialRef.parse(service: "bitbucket", account: "jongyun")
  let envName = try NonEmptyText.parse("BITBUCKET_TOKEN", field: "name")
  let shellPath = try NonEmptyText.parse("~/.zshrc", field: "path")
  let observations = [
    CredentialObservation(
      ref: ref,
      state: .plaintextFallback,
      location: .environment(name: envName)
    ),
    CredentialObservation(
      ref: ref,
      state: .plaintextFallback,
      location: .shellProfile(path: shellPath)
    ),
  ]

  let graph = InventoryGraph(observations: observations)
  let credentialNode = InventoryNode.credential(ref)

  #expect(graph.nodes.contains(credentialNode))
  #expect(graph.nodes.contains(.location(.environment(name: envName))))
  #expect(graph.nodes.contains(.location(.shellProfile(path: shellPath))))
  #expect(
    graph.outgoingEdges(from: credentialNode).map(\.kind) == [
      .hasState,
      .observedIn,
      .observedIn,
    ]
  )
}

@Test
func inventoryGraphDoesNotDuplicateEquivalentEdges() throws {
  let ref = try CredentialRef.parse(service: "openai", account: "jongyun")
  let envName = try NonEmptyText.parse("OPENAI_API_KEY", field: "name")
  let observation = CredentialObservation(
    ref: ref,
    state: .plaintextFallback,
    location: .environment(name: envName)
  )

  let graph = InventoryGraph(observations: [observation, observation])
  let credentialNode = InventoryNode.credential(ref)

  #expect(graph.outgoingEdges(from: credentialNode).count == 2)
}

@Test
func inventoryGraphSummaryCountsGraphProjection() throws {
  let ref = try CredentialRef.parse(service: "openai", account: "jongyun")
  let service = try NonEmptyText.parse("openai", field: "service")
  let account = try NonEmptyText.parse("jongyun", field: "account")
  let envName = try NonEmptyText.parse("OPENAI_API_KEY", field: "name")
  let graph = InventoryGraph(
    observations: [
      CredentialObservation(
        ref: ref,
        state: .plaintextFallback,
        location: .keychain(service: service, account: account)
      ),
      CredentialObservation(
        ref: ref,
        state: .plaintextFallback,
        location: .environment(name: envName)
      ),
    ]
  )

  let summary = InventoryGraphSummary(
    credentialCount: 1,
    locationCount: 2,
    stateCount: 1,
    edgeCount: 3
  )

  #expect(graph.summary == summary)
}

@Test
func inventoryGraphProjectsCredentialsForListAndWhere() throws {
  let openaiRef = try CredentialRef.parse(service: "openai", account: "jongyun")
  let awsRef = try CredentialRef.parse(service: "aws", account: "jongyun")
  let envName = try NonEmptyText.parse("OPENAI_API_KEY", field: "name")
  let configPath = try NonEmptyText.parse("~/.aws/credentials", field: "path")
  let graph = InventoryGraph(
    observations: [
      CredentialObservation(
        ref: openaiRef,
        state: .plaintextFallback,
        location: .environment(name: envName)
      ),
      CredentialObservation(
        ref: awsRef,
        state: .expired,
        location: .configFile(path: configPath)
      ),
    ]
  )

  let projections = graph.credentialProjections
  let openaiProjections = graph.credentialProjections(service: openaiRef.service)
  let expectedOpenaiProjection = CredentialProjection(
    ref: openaiRef,
    states: [.plaintextFallback],
    locations: [.environment(name: envName)]
  )

  #expect(projections.map(\.ref) == [awsRef, openaiRef])
  #expect(openaiProjections == [expectedOpenaiProjection])
}
