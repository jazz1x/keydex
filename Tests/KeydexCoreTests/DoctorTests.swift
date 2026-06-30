import KeydexCore
import Testing

@Test
func doctorFindsUnhealthyStatesFromInventoryGraph() throws {
  let ref = try CredentialRef.parse(service: "openai", account: "jongyun")
  let envName = try NonEmptyText.parse("OPENAI_API_KEY", field: "name")
  let graph = InventoryGraph(
    observations: [
      CredentialObservation(
        ref: ref,
        state: .plaintextFallback,
        location: .environment(name: envName)
      )
    ]
  )

  let issues = CredentialDoctor().inspect(graph)
  let issue = try #require(issues.first)

  #expect(issues.count == 1)
  #expect(issue.severity == .warning)
  #expect(issue.credential == ref)
  #expect(issue.state == .plaintextFallback)
  #expect(issue.locations == [.environment(name: envName)])
  #expect(issue.message == "credential can still be resolved from plaintext configuration")
  #expect(issue.action == "migrate the value to Keychain and remove the plaintext fallback")
}

@Test
func doctorIgnoresRegisteredState() throws {
  let ref = try CredentialRef.parse(service: "openai", account: "jongyun")
  let service = try NonEmptyText.parse("openai", field: "service")
  let account = try NonEmptyText.parse("jongyun", field: "account")
  let graph = InventoryGraph(
    observations: [
      CredentialObservation(
        ref: ref,
        state: .registered,
        location: .keychain(service: service, account: account)
      )
    ]
  )

  #expect(CredentialDoctor().inspect(graph).isEmpty)
}

@Test
func doctorKeepsRecordInspectionAsGraphCompatibilityLayer() throws {
  let ref = try CredentialRef.parse(service: "bitbucket", account: "jongyun")
  let shellPath = try NonEmptyText.parse("~/.zshrc", field: "path")
  let record = CredentialRecord(
    ref: ref,
    state: .plaintextFallback,
    locations: [.shellProfile(path: shellPath)]
  )

  let issue = try #require(CredentialDoctor().inspect([record]).first)

  #expect(issue.credential == ref)
  #expect(issue.locations == [.shellProfile(path: shellPath)])
}

@Test
func doctorClassifiesErrorStates() throws {
  let ref = try CredentialRef.parse(service: "aws", account: "jongyun")
  let path = try NonEmptyText.parse("~/.aws/credentials", field: "path")
  let graph = InventoryGraph(
    observations: [
      CredentialObservation(
        ref: ref,
        state: .expired,
        location: .configFile(path: path)
      )
    ]
  )

  let issue = try #require(CredentialDoctor().inspect(graph).first)

  #expect(issue.severity == .error)
  #expect(issue.state == .expired)
  #expect(issue.message == "credential is expired")
  #expect(issue.action == "rotate or remove the credential")
}
