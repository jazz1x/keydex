import KeydexCore
import KeydexSources
import Testing

@Test
func shellProfileScannerCreatesObservationsWithoutSecretValues() throws {
  let path = try NonEmptyText.parse("~/.zshrc", field: "path")
  let profile = ShellProfile(
    path: path,
    contents: """
      export OPENAI_API_KEY=sk-test-secret
      PATH=/bin
      BITBUCKET_TOKEN=bb-secret
      EMPTY_TOKEN=
      # COMMENTED_TOKEN=hidden
      """
  )

  let observations = try ShellProfileScanner().observations(from: [profile])

  #expect(observations.count == 2)
  #expect(observations.map(\.ref.service.value) == ["openai", "bitbucket"])
  #expect(observations.map(\.ref.account.value) == ["OPENAI_API_KEY", "BITBUCKET_TOKEN"])
  #expect(observations.allSatisfy { $0.state == .plaintextFallback })
  #expect(observations.allSatisfy { $0.location == .shellProfile(path: path) })
  #expect(String(describing: observations).contains("sk-test-secret") == false)
  #expect(String(describing: observations).contains("bb-secret") == false)
}

@Test
func shellProfileScannerAcceptsDirectAssignmentsAndExportAssignments() throws {
  let path = try NonEmptyText.parse("~/.zprofile", field: "path")
  let profile = ShellProfile(
    path: path,
    contents: """
      AWS_ACCESS_KEY_ID=present
      export MARKETBORO_CLIENT_SECRET='present'
      """
  )

  let observations = try ShellProfileScanner().observations(from: [profile])

  #expect(observations.map(\.ref.service.value) == ["aws", "marketboro"])
}
