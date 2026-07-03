import Foundation
import Testing
@testable import KeydexApp

@Test
func shellSettingsStoreSavesAndLoadsConfig() throws {
  let rootURL = temporarySettingsRoot()
  var config = sampleSettingsData(displayMode: .list)
  config.keychainAccess = false
  config.requestPrompt = true
  config.tags = [
    CredentialTagRow(
      id: try #require(UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")),
      name: "Infra",
      assignments: "hashicorp-vault|infra",
      color: .teal
    )
  ]

  try requireSuccess(ShellSettingsStore(rootURL: rootURL).save(config))
  let loaded = ShellSettingsStore(rootURL: rootURL).load(defaults: sampleSettingsData())

  #expect(loaded.issueMessage == nil)
  #expect(loaded.config == config)
}

@Test
func shellSettingsStoreUsesDefaultsWhenManifestIsMissing() {
  let rootURL = temporarySettingsRoot()
  let defaults = sampleSettingsData(displayMode: .cards)

  let loaded = ShellSettingsStore(rootURL: rootURL).load(defaults: defaults)

  #expect(loaded.issueMessage == nil)
  #expect(loaded.config == defaults)
  #expect(FileManager.default.fileExists(atPath: rootURL.path) == false)
}

@Test
func shellSettingsStoreSurfacesUnreadableManifestAsIssue() throws {
  let rootURL = temporarySettingsRoot()
  let defaults = sampleSettingsData(displayMode: .cards)
  try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
  try "{".write(
    to: rootURL.appendingPathComponent("settings.json", isDirectory: false),
    atomically: true,
    encoding: .utf8
  )

  let loaded = ShellSettingsStore(rootURL: rootURL).load(defaults: defaults)

  #expect(loaded.config == defaults)
  #expect(
    loaded.issueMessage
      == "Settings could not be read. Default settings are still available."
  )
}

private func temporarySettingsRoot() -> URL {
  FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
    .appendingPathComponent("Settings", isDirectory: true)
}

private func requireSuccess<T>(
  _ result: Result<T, ShellSettingsStoreError>
) throws -> T {
  switch result {
  case .success(let value):
    return value
  case .failure(let error):
    throw SettingsStoreTestError.unexpectedFailure(error)
  }
}

private enum SettingsStoreTestError: Error {
  case unexpectedFailure(ShellSettingsStoreError)
}
