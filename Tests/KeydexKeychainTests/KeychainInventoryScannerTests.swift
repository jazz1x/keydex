import KeydexCore
import KeydexKeychain
import Testing

@Test
func keychainInventoryScannerCreatesOrphanObservationsWithoutSecretValues() throws {
  let references = [
    try KeychainItemReference(service: "openai", account: "jongyun"),
    try KeychainItemReference(service: "aws", account: "default"),
  ]

  let observations = KeychainInventoryScanner().observations(from: references)
  let graph = InventoryGraph(observations: observations)
  let awsRef = try CredentialRef.parse(service: "aws", account: "default")
  let openaiRef = try CredentialRef.parse(service: "openai", account: "jongyun")

  #expect(observations.map(\.ref) == [awsRef, openaiRef])
  #expect(observations.allSatisfy { $0.state == .orphan })
  #expect(
    observations.map(\.location) == [
      .keychain(service: awsRef.service, account: awsRef.account),
      .keychain(service: openaiRef.service, account: openaiRef.account),
    ]
  )
  #expect(CredentialDoctor().inspect(graph).map(\.state) == [.orphan, .orphan])
  #expect(String(describing: observations).contains("password") == false)
}

@Test
func keychainItemReferenceRejectsBlankServiceOrAccount() {
  #expect(throws: KeydexError.emptyField("service")) {
    try KeychainItemReference(service: " ", account: "jongyun")
  }

  #expect(throws: KeydexError.emptyField("account")) {
    try KeychainItemReference(service: "openai", account: " ")
  }
}
