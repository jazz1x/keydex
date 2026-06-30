import KeydexCore
import SwiftUI

@main
struct KeydexApp: App {
  var body: some Scene {
    WindowGroup("Keydex") {
      CredentialInventoryShellView()
    }
    .defaultSize(width: 1080, height: 680)
  }
}

struct CredentialInventoryShellView: View {
  @State private var selectedSidebar = SidebarSelection.all
  @State private var selectedCredentialID: CredentialRow.ID?

  private let graph = sampleCredentialGraph()

  private var sidebarSelectionItems: [SidebarSelection] {
    let services = Set(graph.credentialProjections.map { $0.ref.service.value }).sorted()
    return [
      .all,
      .state(.expiring),
      .state(.plaintextFallback),
      .state(.orphan),
      .state(.expired),
    ] + services.map { .service($0) }
  }

  private var projectedCredentials: [CredentialProjection] {
    graph.credentialProjections
  }

  private var rows: [CredentialRow] {
    projectedCredentials(for: selectedSidebar)
      .map(CredentialRow.init)
      .sorted { lhs, rhs in
        if lhs.service == rhs.service {
          return lhs.account < rhs.account
        }
        return lhs.service < rhs.service
      }
  }

  private var selectedProjection: CredentialProjection? {
    rows.first { $0.id == selectedCredentialID }
      .map(\.projection)
  }

  private var doctorIssues: [DoctorIssue] {
    CredentialDoctor().inspect(graph).sorted {
      if $0.severity != $1.severity {
        return doctorSeverityOrder($0.severity) < doctorSeverityOrder($1.severity)
      }
      return "\($0.credential.service.value)/\($0.credential.account.value)"
        < "\($1.credential.service.value)/\($1.credential.account.value)"
    }
  }

  var body: some View {
    NavigationSplitView {
      List(sidebarSelectionItems, id: \.self, selection: $selectedSidebar) { item in
        Label(item.title, systemImage: item.systemImage)
          .tag(item)
      }
      .listStyle(.sidebar)
      .navigationTitle("Scopes")
    } content: {
      VStack(spacing: 0) {
        Table(rows, selection: $selectedCredentialID) {
          TableColumn("Service") { row in
            Text(row.service)
          }

          TableColumn("Account") { row in
            Text(row.account)
          }

          TableColumn("State") { row in
            Text(canonicalStateLabel(row.states))
          }

          TableColumn("Sources") { row in
            Text("\(row.locations.count)")
          }
        }
        .navigationTitle(selectedSidebar.title)
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 320)

        Divider()

        DoctorPanel(issues: doctorIssues)
      }
    } detail: {
      VStack(alignment: .leading, spacing: 14) {
        if let projection = selectedProjection {
          Text("Credential")
            .font(.headline)

          VStack(alignment: .leading, spacing: 6) {
            Text("\(projection.ref.service.value)/\(projection.ref.account.value)")
              .font(.title3)
              .fontWeight(.medium)

            Text("States")
              .font(.subheadline)
              .fontWeight(.semibold)

            ForEach(projection.states, id: \.self) { state in
              Text(canonicalStateLabel([state]))
                .foregroundStyle(stateTint(for: state))
            }

            Text("Sources")
              .font(.subheadline)
              .fontWeight(.semibold)
              .padding(.top, 2)

            ForEach(projection.locations, id: \.self) { location in
              Text(locationLabel(location))
                .font(.callout)
                .textSelection(.enabled)
            }
          }
        } else {
          ContentUnavailableView(
            "Select a credential",
            systemImage: "list.bullet.indent",
            description: Text(
              "Choose an item from the table to inspect its graph-derived metadata.")
          )
        }
      }
      .padding(16)
      .frame(minWidth: 260)
    }
  }

  private func projectedCredentials(for selection: SidebarSelection) -> [CredentialProjection] {
    switch selection {
    case .all:
      projectedCredentials
    case .state(let state):
      projectedCredentials.filter { $0.states.contains(state) }
    case .service(let service):
      projectedCredentials.filter { $0.ref.service.value == service }
    }
  }
}

private enum SidebarSelection: Hashable {
  case all
  case state(CredentialState)
  case service(String)

  var title: String {
    switch self {
    case .all:
      "All Credentials"
    case .state(let state):
      "State: \(state.rawValue)"
    case .service(let service):
      service
    }
  }

  var systemImage: String {
    switch self {
    case .all:
      "rectangle.grid.2x2"
    case .state(.expiring):
      "clock.badge.exclamationmark"
    case .state(.plaintextFallback):
      "doc.plaintext"
    case .state(.orphan):
      "person.crop.circle.badge.exclamationmark"
    case .state(.expired):
      "exclamationmark.octagon"
    case .state:
      "circle.dashed"
    case .service:
      "server.rack"
    }
  }
}

private struct CredentialRow: Identifiable {
  let projection: CredentialProjection

  var id: String {
    "\(projection.ref.service.value)|\(projection.ref.account.value)"
  }

  var service: String { projection.ref.service.value }
  var account: String { projection.ref.account.value }
  var states: [CredentialState] { projection.states }
  var locations: [CredentialLocation] { projection.locations }
}

private func canonicalStateLabel(_ states: [CredentialState]) -> String {
  states.map(\.rawValue).sorted().joined(separator: ", ")
}

private struct DoctorIssueRow: Identifiable {
  let issue: DoctorIssue

  var id: String {
    "\(issue.credential.service.value)|\(issue.credential.account.value)|\(issue.state.rawValue)"
  }

  var severityLabel: String {
    issue.severity.rawValue
  }

  var credentialLabel: String {
    "\(issue.credential.service.value)/\(issue.credential.account.value)"
  }

  var stateLabel: String {
    canonicalStateLabel([issue.state])
  }

  var severityTint: Color {
    doctorSeverityTint(issue.severity)
  }
}

private struct DoctorPanel: View {
  let issues: [DoctorIssue]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Doctor")
        .font(.headline)
        .padding(.horizontal, 12)
        .padding(.top, 10)

      if issues.isEmpty {
        Text("No issues found")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
      } else {
        List(issues.map(DoctorIssueRow.init)) { row in
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(row.severityLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(row.severityTint)
              Text(row.credentialLabel)
                .font(.subheadline)
                .fontDesign(.monospaced)
              Spacer()
              Text("state: \(row.stateLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Text("cause: \(row.issue.message)")
              .font(.caption)
              .foregroundStyle(.secondary)

            Text("action: \(row.issue.action)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }
        .listStyle(.plain)
        .frame(minHeight: 170, maxHeight: 220)
      }
    }
  }
}

private func stateTint(for state: CredentialState) -> Color {
  switch state {
  case .missingKeychainItem, .expired:
    .red
  case .plaintextFallback, .orphan, .expiring, .duplicate:
    .orange
  case .registered:
    .green
  }
}

private func doctorSeverityOrder(_ severity: DoctorSeverity) -> Int {
  switch severity {
  case .error:
    0
  case .warning:
    1
  case .info:
    2
  }
}

private func doctorSeverityTint(_ severity: DoctorSeverity) -> Color {
  switch severity {
  case .error:
    .red
  case .warning:
    .orange
  case .info:
    .blue
  }
}

private func locationLabel(_ location: CredentialLocation) -> String {
  switch location {
  case .keychain(let service, let account):
    "\(service.value)/\(account.value) (keychain)"
  case .environment(let name):
    "env: \(name.value)"
  case .shellProfile(let path):
    "shell profile: \(path.value)"
  case .configFile(let path):
    "config file: \(path.value)"
  }
}

private func sampleCredentialGraph() -> InventoryGraph {
  do {
    let openaiRef = try CredentialRef.parse(service: "openai", account: "default")
    let awsRef = try CredentialRef.parse(service: "aws", account: "ci")
    let githubRef = try CredentialRef.parse(service: "github", account: "work")
    let vaultRef = try CredentialRef.parse(service: "hashicorp-vault", account: "infra")
    let npmRef = try CredentialRef.parse(service: "npm", account: "scoped")

    let records: [CredentialRecord] = [
      CredentialRecord(
        ref: openaiRef,
        state: .registered,
        locations: [
          .keychain(service: openaiRef.service, account: openaiRef.account)
        ]
      ),
      CredentialRecord(
        ref: awsRef,
        state: .missingKeychainItem,
        locations: [
          .environment(name: try NonEmptyText.parse("AWS_ACCESS_KEY_ID", field: "name"))
        ]
      ),
      CredentialRecord(
        ref: githubRef,
        state: .plaintextFallback,
        locations: [
          .configFile(path: try NonEmptyText.parse("~/.config/gh/config", field: "path"))
        ]
      ),
      CredentialRecord(
        ref: vaultRef,
        state: .expired,
        locations: [
          .shellProfile(path: try NonEmptyText.parse("~/.zshrc", field: "path")),
          .environment(name: try NonEmptyText.parse("VAULT_TOKEN", field: "name")),
        ]
      ),
      CredentialRecord(
        ref: npmRef,
        state: .orphan,
        locations: [
          .keychain(service: npmRef.service, account: npmRef.account)
        ]
      ),
      CredentialRecord(
        ref: try CredentialRef.parse(service: "acme", account: "staging"),
        state: .duplicate,
        locations: [
          .environment(name: try NonEmptyText.parse("ACME_API_KEY", field: "name"))
        ]
      ),
      CredentialRecord(
        ref: try CredentialRef.parse(service: "expiring-service", account: "preview"),
        state: .expiring,
        locations: [
          .configFile(path: try NonEmptyText.parse("~/.expiring/config", field: "path"))
        ]
      ),
    ]

    return InventoryGraph(records: records)
  } catch {
    preconditionFailure("Invalid checked-in sample credential graph: \(error)")
  }
}
