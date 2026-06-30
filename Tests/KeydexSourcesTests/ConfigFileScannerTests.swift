import KeydexCore
import KeydexSources
import Testing

@Test
func configFileScannerCreatesObservationsWithoutSecretValues() throws {
  let path = try NonEmptyText.parse("~/.config/example.env", field: "path")
  let file = ConfigFile(
    path: path,
    contents: """
      OPENAI_API_KEY=sk-test-secret
      PATH=/bin
      BITBUCKET_TOKEN=bb-secret
      EMPTY_TOKEN=
      # COMMENTED_TOKEN=hidden
      """
  )

  let observations = try ConfigFileScanner().observations(from: [file])

  #expect(observations.count == 2)
  #expect(observations.map(\.ref.service.value) == ["openai", "bitbucket"])
  #expect(observations.map(\.ref.account.value) == ["OPENAI_API_KEY", "BITBUCKET_TOKEN"])
  #expect(observations.allSatisfy { $0.state == .plaintextFallback })
  #expect(observations.allSatisfy { $0.location == .configFile(path: path) })
  #expect(String(describing: observations).contains("sk-test-secret") == false)
  #expect(String(describing: observations).contains("bb-secret") == false)
}

@Test
func configFileScannerKeepsStableCredentialOrder() throws {
  let path = try NonEmptyText.parse("credentials.env", field: "path")
  let file = ConfigFile(
    path: path,
    contents: """
      AWS_ACCESS_KEY_ID=present
      MARKETBORO_CLIENT_SECRET=present
      """
  )

  let observations = try ConfigFileScanner().observations(from: [file])

  #expect(observations.map(\.ref.service.value) == ["aws", "marketboro"])
}
