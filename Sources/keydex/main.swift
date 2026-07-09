import ArgumentParser
import Darwin
import Foundation
import KeydexCore
import KeydexKeychain
import KeydexRuntime
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
      Reminders.self,
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
      print(CLIStyle.info("keydex list: no credentials indexed yet"))
    } else {
      for projection in projections {
        print(
          "\(stateSymbol(projection.states)) \(projection.ref.service)/\(projection.ref.account)  \(stateLabels(projection.states))  \(projection.locations.count) sources"
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
      print(CLIStyle.info("keydex where: \(parsedService) is not indexed yet"))
    } else {
      for projection in projections {
        print(
          "\(stateSymbol(projection.states)) \(projection.ref.service)/\(projection.ref.account): \(stateLabels(projection.states))"
        )
        for location in projection.locations {
          print(CLIStyle.detail(locationLabel(location)))
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
      print(CLIStyle.success("keydex doctor: clean"))
    } else {
      for issue in issues {
        print(
          """
          \(severitySymbol(issue.severity)) \(issue.severity.rawValue): \(issue.credential.service)/\(issue.credential.account) \(issue.state.rawValue)
          \(CLIStyle.detail("cause: \(issue.message)"))
          \(CLIStyle.detail("action: \(issue.action)"))
          """
        )
      }
    }
  }
}

struct Reminders: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Show configured expiry reminder notifications.")

  @Option(help: "Path to a Keydex metadata JSON file.")
  var metadata: String?

  @Option(help: "Override current date for evidence runs, formatted as YYYY-MM-DD.")
  var now: String?

  func run() async throws {
    let currentDate = try currentDateOverride(now)
    let records = try await credentialRecords(metadataPath: metadata, currentDate: currentDate)
    let reminders = CredentialExpiryReminderPlanner().reminders(
      from: records,
      currentDate: currentDate
    )

    if reminders.isEmpty {
      print(CLIStyle.info("keydex reminders: no expiry reminders configured"))
    } else {
      for reminder in reminders {
        print(
          """
          \(reminderSymbol(reminder.status)) \(reminder.status.rawValue): \(reminder.credential.service)/\(reminder.credential.account) expires \(fullDateString(reminder.expiresAt))
          \(CLIStyle.detail("notify: \(fullDateString(reminder.notifyAt)) (\(reminder.notifyBeforeDays)d before)"))
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
  let keychainObservations: [CredentialObservation]
  if includeKeychain {
    let keychainReferences = try MacOSKeychain().inventoryReferences()
    keychainObservations = KeychainInventoryScanner().observations(from: keychainReferences)
  } else {
    keychainObservations = []
  }

  return try await LocalInventoryGraphBuilder().graph(
    for: LocalInventoryGraphRequest(
      metadataURL: try metadataURL(metadataPath: metadataPath),
      keychainObservations: keychainObservations,
      reconcilesKeychainReferences: includeKeychain
    )
  )
}

private func metadataURL(metadataPath: String?) throws -> URL? {
  guard let metadataPath else {
    return nil
  }

  let path = try NonEmptyText.parse(metadataPath, field: "metadata")
  return URL(fileURLWithPath: path.value)
}

private func credentialRecords(
  metadataPath: String?,
  currentDate: Date = Date()
) async throws -> [CredentialRecord] {
  guard let metadataPath else {
    return try await EmptyMetadataStore().listCredentials()
  }

  let path = try NonEmptyText.parse(metadataPath, field: "metadata")
  let url = URL(fileURLWithPath: path.value)
  return try await FileMetadataStore(url: url, currentDate: currentDate).listCredentials()
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

private func stateSymbol(_ states: [CredentialState]) -> String {
  stateSymbol(states.sorted(by: stateSeveritySort).first)
}

private func stateSymbol(_ state: CredentialState?) -> String {
  switch state {
  case .registered:
    CLIStyle.successTone("✓")
  case .missingKeychainItem, .expired:
    CLIStyle.error("■")
  case .plaintextFallback, .orphan, .expiring, .duplicate:
    CLIStyle.warning("⚠")
  case nil:
    CLIStyle.infoTone("◇")
  }
}

private func stateSeveritySort(_ left: CredentialState, _ right: CredentialState) -> Bool {
  stateSeverityOrder(left) < stateSeverityOrder(right)
}

private func stateSeverityOrder(_ state: CredentialState) -> Int {
  switch state {
  case .missingKeychainItem, .expired:
    0
  case .plaintextFallback, .orphan, .expiring, .duplicate:
    1
  case .registered:
    2
  }
}

private func severitySymbol(_ severity: DoctorSeverity) -> String {
  switch severity {
  case .info:
    CLIStyle.infoTone("◇")
  case .warning:
    CLIStyle.warning("⚠")
  case .error:
    CLIStyle.error("■")
  }
}

private func reminderSymbol(_ status: CredentialExpiryReminderStatus) -> String {
  switch status {
  case .scheduled:
    CLIStyle.infoTone("◇")
  case .due:
    CLIStyle.warning("⚠")
  case .expired:
    CLIStyle.error("■")
  }
}

private func currentDateOverride(_ value: String?) throws -> Date {
  guard let value else {
    return Date()
  }

  guard let date = fullDateFormatter().date(from: value) else {
    throw ValidationError("--now must be formatted as YYYY-MM-DD")
  }

  return date
}

private func fullDateString(_ date: Date) -> String {
  fullDateFormatter().string(from: date)
}

private func fullDateFormatter() -> ISO8601DateFormatter {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withFullDate]
  return formatter
}

private func locationLabel(_ location: CredentialLocation) -> String {
  switch location {
  case .keychain(let service, let account):
    "[keychain] \(service)/\(account)"
  case .environment(let name):
    "[env] \(name)"
  case .shellProfile(let path):
    "[shell] \(path)"
  case .configFile(let path):
    "[config] \(path)"
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
        \(CLIStyle.run("keydex scan env: \(summary.credentialCount) credential hints"))
        \(CLIStyle.detail("[graph] sources \(summary.locationCount) · edges \(summary.edgeCount)"))
        """
      )
    case "shell":
      let observations = try ShellProfileScanner().observations(from: defaultShellProfiles())
      let summary = InventoryGraph(observations: observations).summary
      print(
        """
        \(CLIStyle.run("keydex scan shell: \(summary.credentialCount) credential hints"))
        \(CLIStyle.detail("[graph] sources \(summary.locationCount) · edges \(summary.edgeCount)"))
        """
      )
    case "config":
      let observations = try ConfigFileScanner().observations(
        from: configFiles(paths: path))
      let summary = InventoryGraph(observations: observations).summary
      print(
        """
        \(CLIStyle.run("keydex scan config: \(summary.credentialCount) credential hints"))
        \(CLIStyle.detail("[graph] sources \(summary.locationCount) · edges \(summary.edgeCount)"))
        """
      )
    case "keychain":
      let references = try MacOSKeychain().inventoryReferences()
      let observations = KeychainInventoryScanner().observations(from: references)
      let summary = InventoryGraph(observations: observations).summary
      print(
        """
        \(CLIStyle.run("keydex scan keychain: \(summary.credentialCount) credential references"))
        \(CLIStyle.detail("[graph] sources \(summary.locationCount) · edges \(summary.edgeCount)"))
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

private enum CLIStyle {
  private enum ANSI: String {
    case reset = "\u{001B}[0m"
    case cyan = "\u{001B}[36m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case red = "\u{001B}[31m"
    case dim = "\u{001B}[38;5;245m"
  }

  private static var colorEnabled: Bool {
    let environment = ProcessInfo.processInfo.environment
    return isatty(STDOUT_FILENO) == 1
      && environment["NO_COLOR"] == nil
      && environment["TERM"] != "dumb"
  }

  static func run(_ text: String) -> String {
    "\(infoTone("◇"))  \(text)"
  }

  static func info(_ text: String) -> String {
    "\(infoTone("◇"))  \(text)"
  }

  static func success(_ text: String) -> String {
    "\(successTone("✓"))  \(text)"
  }

  static func detail(_ text: String) -> String {
    "\(color("│", .dim))  \(text)"
  }

  static func infoTone(_ text: String) -> String {
    color(text, .cyan)
  }

  static func successTone(_ text: String) -> String {
    color(text, .green)
  }

  static func warning(_ text: String) -> String {
    color(text, .yellow)
  }

  static func error(_ text: String) -> String {
    color(text, .red)
  }

  private static func color(_ text: String, _ ansi: ANSI) -> String {
    guard colorEnabled else {
      return text
    }

    return "\(ansi.rawValue)\(text)\(ANSI.reset.rawValue)"
  }
}
