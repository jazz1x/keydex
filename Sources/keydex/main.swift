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

  @Option(help: "Path to a Keydex metadata JSON file.")
  var metadata: String?

  func run() async throws {
    let records = try await credentialRecords(metadataPath: metadata)
    let projections = InventoryGraph(records: records).credentialProjections
    if projections.isEmpty {
      print("keydex: no credentials indexed yet")
    } else {
      for projection in projections {
        print(
          "\(projection.ref.service)\t\(projection.ref.account)\t\(stateLabels(projection.states))\t\(projection.locations.count) sources"
        )
      }
    }
  }
}

struct Where: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Show where a credential resolves from.")

  @Argument(help: "Service name, such as openai or bitbucket.")
  var service: String

  @Option(help: "Path to a Keydex metadata JSON file.")
  var metadata: String?

  func run() async throws {
    let parsedService = try NonEmptyText.parse(service, field: "service")
    let records = try await credentialRecords(metadataPath: metadata)
    let projections = InventoryGraph(records: records).credentialProjections(
      service: parsedService)

    if projections.isEmpty {
      print("keydex: where \(parsedService) is not indexed yet")
    } else {
      for projection in projections {
        print(
          "\(projection.ref.service)/\(projection.ref.account): \(stateLabels(projection.states))"
        )
        for location in projection.locations {
          print("  \(locationLabel(location))")
        }
      }
    }
  }
}

struct Doctor: AsyncParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Diagnose credential inventory drift.")

  @Option(help: "Path to a Keydex metadata JSON file.")
  var metadata: String?

  func run() async throws {
    let records = try await credentialRecords(metadataPath: metadata)
    let graph = InventoryGraph(records: records)
    let issues = CredentialDoctor().inspect(graph)
    if issues.isEmpty {
      print("keydex doctor: no issues found")
    } else {
      for issue in issues {
        print(
          """
          \(issue.severity.rawValue): \(issue.credential.service)/\(issue.credential.account) \(issue.state.rawValue)
            cause: \(issue.message)
            action: \(issue.action)
          """
        )
      }
    }
  }
}

private func credentialRecords(metadataPath: String?) async throws -> [CredentialRecord] {
  guard let metadataPath else {
    return try await EmptyMetadataStore().listCredentials()
  }

  let path = try NonEmptyText.parse(metadataPath, field: "metadata")
  let url = URL(fileURLWithPath: path.value)
  return try await FileMetadataStore(url: url).listCredentials()
}

private func stateLabels(_ states: [CredentialState]) -> String {
  if states.isEmpty {
    "no-state-edge"
  } else {
    states.map(\.rawValue).joined(separator: ",")
  }
}

private func locationLabel(_ location: CredentialLocation) -> String {
  switch location {
  case .keychain(let service, let account):
    "keychain \(service)/\(account)"
  case .environment(let name):
    "env \(name)"
  case .shellProfile(let path):
    "shell \(path)"
  case .configFile(let path):
    "config \(path)"
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
      let summary = InventoryGraph(observations: observations).summary
      print(
        """
        keydex scan env: \(summary.credentialCount) credential hints
        graph: \(summary.locationCount) sources, \(summary.edgeCount) edges
        """
      )
    case "shell":
      let observations = try ShellProfileScanner().observations(from: defaultShellProfiles())
      let summary = InventoryGraph(observations: observations).summary
      print(
        """
        keydex scan shell: \(summary.credentialCount) credential hints
        graph: \(summary.locationCount) sources, \(summary.edgeCount) edges
        """
      )
    case "config":
      print("keydex scan \(parsedTarget): not implemented yet")
    default:
      throw ValidationError("scan target must be env, shell, or config")
    }
  }

  private func defaultShellProfiles() throws -> [ShellProfile] {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let profileNames = [".zshrc", ".zprofile", ".bash_profile", ".bashrc"]
    var profiles: [ShellProfile] = []

    for profileName in profileNames {
      let url = home.appendingPathComponent(profileName)
      if FileManager.default.fileExists(atPath: url.path) {
        let path = try NonEmptyText.parse(url.path, field: "path")
        let contents = try String(contentsOf: url, encoding: .utf8)
        profiles.append(ShellProfile(path: path, contents: contents))
      }
    }

    return profiles
  }
}
