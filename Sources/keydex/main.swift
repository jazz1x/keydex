import ArgumentParser
import Foundation
import KeydexCore
import KeydexSources
import KeydexStore

@main
struct Keydex: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Mac developer credential inventory.",
    discussion: "Credentials should tell the truth about where they live.",
    subcommands: [
      List.self,
      Where.self,
      Doctor.self,
      Scan.self,
    ]
  )
}

struct List: AsyncParsableCommand {
  static let configuration = CommandConfiguration(abstract: "List indexed credentials.")

  func run() async throws {
    let records = try await EmptyMetadataStore().listCredentials()
    if records.isEmpty {
      print("keydex: no credentials indexed yet")
    }
  }
}

struct Where: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Show where a credential resolves from.")

  @Argument(help: "Service name, such as openai or bitbucket.")
  var service: String

  func run() throws {
    _ = try NonEmptyText.parse(service, field: "service")
    print("keydex: where \(service) is not indexed yet")
  }
}

struct Doctor: AsyncParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Diagnose credential inventory drift.")

  func run() async throws {
    let records = try await EmptyMetadataStore().listCredentials()
    let issues = CredentialDoctor().inspect(records)
    if issues.isEmpty {
      print("keydex doctor: no issues found")
    }
  }
}

struct Scan: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Scan local configuration for credential hints.")

  @Argument(help: "Scan target: env, shell, or config.")
  var target: String

  func run() throws {
    let parsedTarget = try NonEmptyText.parse(target, field: "target")

    switch parsedTarget.value {
    case "env":
      let observations = try EnvironmentScanner().observations(
        from: ProcessInfo.processInfo.environment)
      print("keydex scan env: \(observations.count) credential hints")
    case "shell", "config":
      print("keydex scan \(parsedTarget): not implemented yet")
    default:
      throw ValidationError("scan target must be env, shell, or config")
    }
  }
}
