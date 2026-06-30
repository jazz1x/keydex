import KeydexCore
import KeydexSources
import Testing

@Test
func environmentScannerCreatesPlaintextObservationsWithoutSecretValues() throws {
  let observations = try EnvironmentScanner().observations(
    from: [
      "OPENAI_API_KEY": "sk-test-secret",
      "PATH": "/bin",
      "EMPTY_TOKEN": "",
    ]
  )

  let observation = try #require(observations.first)
  let environmentName = try NonEmptyText.parse("OPENAI_API_KEY", field: "name")

  #expect(observations.count == 1)
  #expect(observation.ref.service.value == "openai")
  #expect(observation.ref.account.value == "OPENAI_API_KEY")
  #expect(observation.state == .plaintextFallback)
  #expect(observation.location == .environment(name: environmentName))
  #expect(String(describing: observations).contains("sk-test-secret") == false)
}

@Test
func environmentScannerKeepsStableServiceNamesForCommonCredentialSuffixes() throws {
  let observations = try EnvironmentScanner().observations(
    from: [
      "AWS_ACCESS_KEY_ID": "present",
      "MARKETBORO_CLIENT_SECRET": "present",
      "SLACK_TOKEN": "present",
    ]
  )

  #expect(observations.map(\.ref.service.value) == ["aws", "marketboro", "slack"])
  #expect(
    observations.map(\.ref.account.value) == [
      "AWS_ACCESS_KEY_ID",
      "MARKETBORO_CLIENT_SECRET",
      "SLACK_TOKEN",
    ]
  )
}
