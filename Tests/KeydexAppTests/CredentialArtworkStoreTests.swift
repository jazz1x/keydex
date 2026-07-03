import Foundation
import Testing
@testable import KeydexApp

@Test
func credentialArtworkStoreImportsAndLoadsManifest() throws {
  let rootURL = temporaryArtworkRoot()
  let sourceURL = try writeArtworkFixture(named: "keydex-card.png")
  let store = CredentialArtworkStore(rootURL: rootURL)

  let override = try requireSuccess(
    store.importArtwork(
      from: sourceURL,
      credentialID: "aws/ci",
      existingOverrides: [:]
    )
  )
  let loaded = CredentialArtworkStore(rootURL: rootURL).loadOverrides()

  #expect(override.credentialID == "aws/ci")
  #expect(override.fileName == "aws-ci-6177732f6369.png")
  #expect(FileManager.default.fileExists(atPath: override.fileURL(rootURL: rootURL).path))
  #expect(loaded.issueMessage == nil)
  #expect(loaded.overrides["aws/ci"] == override)
}

@Test
func credentialArtworkStoreRejectsUnsupportedImageTypes() throws {
  let rootURL = temporaryArtworkRoot()
  let sourceURL = try writeArtworkFixture(named: "notes.txt")
  let result = CredentialArtworkStore(rootURL: rootURL).importArtwork(
    from: sourceURL,
    credentialID: "aws/ci",
    existingOverrides: [:]
  )

  #expect(result == .failure(.unsupportedImageType("txt")))
  #expect(FileManager.default.fileExists(atPath: rootURL.path) == false)
}

@Test
func credentialArtworkStoreKeepsSimilarCredentialIDsInDistinctFiles() throws {
  let rootURL = temporaryArtworkRoot()
  let sourceURL = try writeArtworkFixture(named: "keydex-card.png")
  let store = CredentialArtworkStore(rootURL: rootURL)

  let slashOverride = try requireSuccess(
    store.importArtwork(
      from: sourceURL,
      credentialID: "aws/ci",
      existingOverrides: [:]
    )
  )
  let dashOverride = try requireSuccess(
    store.importArtwork(
      from: sourceURL,
      credentialID: "aws-ci",
      existingOverrides: ["aws/ci": slashOverride]
    )
  )
  let loaded = store.loadOverrides()

  #expect(slashOverride.fileName == "aws-ci-6177732f6369.png")
  #expect(dashOverride.fileName == "aws-ci-6177732d6369.png")
  #expect(slashOverride.fileName != dashOverride.fileName)
  #expect(FileManager.default.fileExists(atPath: slashOverride.fileURL(rootURL: rootURL).path))
  #expect(FileManager.default.fileExists(atPath: dashOverride.fileURL(rootURL: rootURL).path))
  #expect(loaded.overrides["aws/ci"] == slashOverride)
  #expect(loaded.overrides["aws-ci"] == dashOverride)
}

@Test
func credentialArtworkStoreRemovesPreviousFileWhenReplacingArtwork() throws {
  let rootURL = temporaryArtworkRoot()
  let firstSourceURL = try writeArtworkFixture(named: "first.png")
  let secondSourceURL = try writeArtworkFixture(named: "second.jpeg")
  let store = CredentialArtworkStore(rootURL: rootURL)
  let firstOverride = try requireSuccess(
    store.importArtwork(
      from: firstSourceURL,
      credentialID: "github/work",
      existingOverrides: [:]
    )
  )

  let secondOverride = try requireSuccess(
    store.importArtwork(
      from: secondSourceURL,
      credentialID: "github/work",
      existingOverrides: ["github/work": firstOverride]
    )
  )
  let loaded = store.loadOverrides()

  #expect(firstOverride.fileName == "github-work-6769746875622f776f726b.png")
  #expect(secondOverride.fileName == "github-work-6769746875622f776f726b.jpeg")
  #expect(
    FileManager.default.fileExists(atPath: firstOverride.fileURL(rootURL: rootURL).path) == false
  )
  #expect(FileManager.default.fileExists(atPath: secondOverride.fileURL(rootURL: rootURL).path))
  #expect(loaded.overrides["github/work"] == secondOverride)
}

@Test
func credentialArtworkStoreRemovesArtworkAndManifestEntry() throws {
  let rootURL = temporaryArtworkRoot()
  let sourceURL = try writeArtworkFixture(named: "card.jpeg")
  let store = CredentialArtworkStore(rootURL: rootURL)
  let override = try requireSuccess(
    store.importArtwork(
      from: sourceURL,
      credentialID: "github/work",
      existingOverrides: [:]
    )
  )

  let removeResult = store.removeArtwork(
    for: "github/work",
    existingOverrides: ["github/work": override]
  )
  try requireSuccess(removeResult)
  let loaded = store.loadOverrides()

  #expect(FileManager.default.fileExists(atPath: override.fileURL(rootURL: rootURL).path) == false)
  #expect(loaded.overrides.isEmpty)
  #expect(loaded.issueMessage == nil)
}

@Test
func credentialArtworkStoreSurfacesUnreadableManifestAsIssue() throws {
  let rootURL = temporaryArtworkRoot()
  try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
  try "{".write(
    to: rootURL.appendingPathComponent("manifest.json"),
    atomically: true,
    encoding: .utf8
  )

  let loaded = CredentialArtworkStore(rootURL: rootURL).loadOverrides()

  #expect(loaded.overrides.isEmpty)
  #expect(
    loaded.issueMessage
      == "Custom artwork manifest could not be read. Default artwork is still available."
  )
}

@Test
func credentialArtworkOverrideResolvesFileNamesInsideArtworkRoot() {
  let rootURL = temporaryArtworkRoot()
  let override = CredentialArtworkOverride(
    credentialID: "aws/ci",
    fileName: "../outside.png"
  )

  #expect(
    override.fileURL(rootURL: rootURL).standardizedFileURL
      == rootURL.appendingPathComponent("outside.png").standardizedFileURL
  )
}

private func temporaryArtworkRoot() -> URL {
  FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
    .appendingPathComponent("Artwork", isDirectory: true)
}

private func writeArtworkFixture(named fileName: String) throws -> URL {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

  let url = directory.appendingPathComponent(fileName, isDirectory: false)
  try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
  return url
}

private func requireSuccess<T>(
  _ result: Result<T, CredentialArtworkStoreError>
) throws -> T {
  switch result {
  case .success(let value):
    return value
  case .failure(let error):
    throw ArtworkStoreTestError.unexpectedFailure(error)
  }
}

private enum ArtworkStoreTestError: Error {
  case unexpectedFailure(CredentialArtworkStoreError)
}
