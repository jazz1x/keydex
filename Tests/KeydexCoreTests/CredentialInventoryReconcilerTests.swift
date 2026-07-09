import KeydexCore
import Testing

@Test
func reconcilerMarksMatchedMetadataKeychainLocationRegistered() throws {
  let ref = try CredentialRef.parse(service: "openai", account: "jongyun")
  let keychainLocation = CredentialLocation.keychain(
    service: ref.service,
    account: ref.account
  )
  let metadataRecord = CredentialRecord(
    ref: ref,
    state: .missingKeychainItem,
    locations: [keychainLocation]
  )
  let keychainObservation = CredentialObservation(
    ref: ref,
    state: .orphan,
    location: keychainLocation
  )

  let graph = CredentialInventoryReconciler().graph(
    metadataRecords: [metadataRecord],
    keychainObservations: [keychainObservation]
  )

  let projection = try #require(graph.credentialProjections.first)

  #expect(projection.states == [.registered])
  #expect(projection.locations == [keychainLocation])
  #expect(CredentialDoctor().inspect(graph).isEmpty)
}

@Test
func reconcilerMarksMissingMetadataKeychainLocation() throws {
  let ref = try CredentialRef.parse(service: "bitbucket", account: "jongyun")
  let keychainLocation = CredentialLocation.keychain(
    service: ref.service,
    account: ref.account
  )
  let metadataRecord = CredentialRecord(
    ref: ref,
    state: .registered,
    locations: [keychainLocation]
  )

  let graph = CredentialInventoryReconciler().graph(
    metadataRecords: [metadataRecord],
    keychainObservations: []
  )
  let issue = try #require(CredentialDoctor().inspect(graph).first)

  #expect(issue.state == .missingKeychainItem)
  #expect(issue.locations == [keychainLocation])
}

@Test
func reconcilerKeepsUnmatchedKeychainObservationAsOrphan() throws {
  let ref = try CredentialRef.parse(service: "aws", account: "default")
  let keychainLocation = CredentialLocation.keychain(
    service: ref.service,
    account: ref.account
  )
  let keychainObservation = CredentialObservation(
    ref: ref,
    state: .orphan,
    location: keychainLocation
  )

  let graph = CredentialInventoryReconciler().graph(
    metadataRecords: [],
    keychainObservations: [keychainObservation]
  )
  let issue = try #require(CredentialDoctor().inspect(graph).first)

  #expect(issue.state == .orphan)
  #expect(issue.locations == [keychainLocation])
}

@Test
func reconcilerPreservesNonKeychainMetadataLocations() throws {
  let ref = try CredentialRef.parse(service: "openai", account: "jongyun")
  let envName = try NonEmptyText.parse("OPENAI_API_KEY", field: "name")
  let keychainLocation = CredentialLocation.keychain(
    service: ref.service,
    account: ref.account
  )
  let metadataRecord = CredentialRecord(
    ref: ref,
    state: .plaintextFallback,
    locations: [
      .environment(name: envName),
      keychainLocation,
    ]
  )
  let keychainObservation = CredentialObservation(
    ref: ref,
    state: .orphan,
    location: keychainLocation
  )

  let graph = CredentialInventoryReconciler().graph(
    metadataRecords: [metadataRecord],
    keychainObservations: [keychainObservation]
  )
  let projection = try #require(graph.credentialProjections.first)

  #expect(projection.states == [.plaintextFallback, .registered])
  #expect(
    projection.locations == [
      .environment(name: envName),
      keychainLocation,
    ]
  )
}

@Test
func reconcilerMergesAdditionalSourceObservations() throws {
  let ref = try CredentialRef.parse(service: "openai", account: "default")
  let keychainLocation = CredentialLocation.keychain(
    service: ref.service,
    account: ref.account
  )
  let metadataRecord = CredentialRecord(
    ref: ref,
    state: .missingKeychainItem,
    locations: [keychainLocation]
  )
  let environmentName = try NonEmptyText.parse("OPENAI_API_KEY", field: "name")
  let environmentObservation = CredentialObservation(
    ref: try CredentialRef.parse(service: "openai", account: "OPENAI_API_KEY"),
    state: .plaintextFallback,
    location: .environment(name: environmentName)
  )

  let graph = CredentialInventoryReconciler().graph(
    metadataRecords: [metadataRecord],
    keychainObservations: [],
    additionalObservations: [environmentObservation]
  )

  #expect(graph.credentialProjections.map(\.ref.service.value) == ["openai", "openai"])
  #expect(
    graph.credentialProjections.flatMap(\.states)
      == [.plaintextFallback, .missingKeychainItem]
  )
}
