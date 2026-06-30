import ArgumentParser
import Foundation
import KeydexCore
import KeydexKeychain
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

  @Flag(help: "Include live Keychain item references.")
  var includeKeychain = false

  func run() async throws {
    let projections = try await credentialGraph(
      metadataPath: metadata,
      includeKeychain: includeKeychain
    ).credentialProjections
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

  @Flag(help: "Include live Keychain item references.")
  var includeKeychain = false

  func run() async throws {
    let parsedService = try NonEmptyText.parse(service, field: "service")
    let projections = try await credentialGraph(
      metadataPath: metadata,
      includeKeychain: includeKeychain
    ).credentialProjections(service: parsedService)

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

  @Flag(help: "Include live Keychain item references.")
  var includeKeychain = false

  func run() async throws {
    let graph = try await credentialGraph(
      metadataPath: metadata,
      includeKeychain: includeKeychain
    )
    let ignoredCredentials = try await ignoredCredentials(metadataPath: metadata)
    let issues = CredentialDoctor().inspect(graph, ignoring: ignoredCredentials)
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

private func credentialGraph(
  metadataPath: String?,
  includeKeychain: Bool
) async throws -> InventoryGraph {
  let records = try await credentialRecords(metadataPath: metadataPath)

  if includeKeychain {
    let keychainReferences = try MacOSKeychain().inventoryReferences()
    let keychainObservations = KeychainInventoryScanner().observations(from: keychainReferences)
    return CredentialInventoryReconciler().graph(
      metadataRecords: records,
      keychainObservations: keychainObservations
    )
  }

  return InventoryGraph(records: records)
}

private func credentialRecords(metadataPath: String?) async throws -> [CredentialRecord] {
  guard let metadataPath else {
    return try await EmptyMetadataStore().listCredentials()
  }

  let path = try NonEmptyText.parse(metadataPath, field: "metadata")
  let url = URL(fileURLWithPath: path.value)
  return try await FileMetadataStore(url: url).listCredentials()
}

private func ignoredCredentials(metadataPath: String?) async throws -> Set<CredentialRef> {
  guard let metadataPath else {
    return try await EmptyMetadataStore().ignoredCredentials()
  }

  let path = try NonEmptyText.parse(metadataPath, field: "metadata")
  let url = URL(fileURLWithPath: path.value)
  return try await FileMetadataStore(url: url).ignoredCredentials()
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

  @Argument(help: "Scan target: env, shell, config, or keychain.")
  var target: String

  @Option(help: "Config file path to scan. Repeat for multiple files.")
  var path: [String] = []

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
      let observations = try ConfigFileScanner().observations(
        from: configFiles(paths: path))
      let summary = InventoryGraph(observations: observations).summary
      print(
        """
        keydex scan config: \(summary.credentialCount) credential hints
        graph: \(summary.locationCount) sources, \(summary.edgeCount) edges
        """
      )
    case "keychain":
      let references = try MacOSKeychain().inventoryReferences()
      let observations = KeychainInventoryScanner().observations(from: references)
      let summary = InventoryGraph(observations: observations).summary
      print(
        """
        keydex scan keychain: \(summary.credentialCount) credential references
        graph: \(summary.locationCount) sources, \(summary.edgeCount) edges
        """
      )
    default:
      throw ValidationError("scan target must be env, shell, config, or keychain")
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

  private func configFiles(paths: [String]) throws -> [ConfigFile] {
    if paths.isEmpty {
      throw ValidationError("scan config requires at least one --path")
    }

    return try paths.map { rawPath in
      let path = try NonEmptyText.parse(rawPath, field: "path")
      let url = URL(fileURLWithPath: path.value)
      let contents = try String(contentsOf: url, encoding: .utf8)
      return ConfigFile(path: path, contents: contents)
    }
  }
}
