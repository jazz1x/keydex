public enum DoctorSeverity: String, Equatable, Sendable {
  case info
  case warning
  case error
}

public struct DoctorIssue: Equatable, Sendable {
  public let severity: DoctorSeverity
  public let credential: CredentialRef
  public let state: CredentialState
  public let locations: [CredentialLocation]
  public let message: String
  public let action: String

  public init(
    severity: DoctorSeverity,
    credential: CredentialRef,
    state: CredentialState,
    locations: [CredentialLocation],
    message: String,
    action: String
  ) {
    self.severity = severity
    self.credential = credential
    self.state = state
    self.locations = locations
    self.message = message
    self.action = action
  }
}

public struct CredentialDoctor: Sendable {
  public init() {}

  public func inspect(_ records: [CredentialRecord]) -> [DoctorIssue] {
    inspect(InventoryGraph(records: records))
  }

  public func inspect(
    _ records: [CredentialRecord],
    ignoring ignoredCredentials: Set<CredentialRef>
  ) -> [DoctorIssue] {
    inspect(InventoryGraph(records: records), ignoring: ignoredCredentials)
  }

  public func inspect(_ graph: InventoryGraph) -> [DoctorIssue] {
    inspect(graph, ignoring: [])
  }

  public func inspect(
    _ graph: InventoryGraph,
    ignoring ignoredCredentials: Set<CredentialRef>
  ) -> [DoctorIssue] {
    graph.edges.compactMap { edge in
      issue(for: edge, in: graph, ignoring: ignoredCredentials)
    }
  }

  private func issue(
    for edge: InventoryEdge,
    in graph: InventoryGraph,
    ignoring ignoredCredentials: Set<CredentialRef>
  ) -> DoctorIssue? {
    guard edge.kind == .hasState else {
      return nil
    }

    guard case .credential(let credential) = edge.from else {
      return nil
    }

    if ignoredCredentials.contains(credential) {
      return nil
    }

    guard case .state(let state) = edge.to else {
      return nil
    }

    return issue(
      credential: credential,
      state: state,
      locations: locations(for: edge.from, in: graph)
    )
  }

  private func issue(
    credential: CredentialRef,
    state: CredentialState,
    locations: [CredentialLocation]
  ) -> DoctorIssue? {
    switch state {
    case .registered:
      nil
    case .missingKeychainItem:
      DoctorIssue(
        severity: .error,
        credential: credential,
        state: state,
        locations: locations,
        message: "metadata points at a Keychain item that is missing",
        action: "register the real Keychain item or remove stale metadata"
      )
    case .plaintextFallback:
      DoctorIssue(
        severity: .warning,
        credential: credential,
        state: state,
        locations: locations,
        message: "credential can still be resolved from plaintext configuration",
        action: "migrate the value to Keychain and remove the plaintext fallback"
      )
    case .orphan:
      DoctorIssue(
        severity: .warning,
        credential: credential,
        state: state,
        locations: locations,
        message: "Keychain item exists without Keydex metadata",
        action: "register metadata or mark the item as intentionally unmanaged"
      )
    case .expiring:
      DoctorIssue(
        severity: .warning,
        credential: credential,
        state: state,
        locations: locations,
        message: "credential is nearing its expiry date",
        action: "rotate the credential before it expires"
      )
    case .expired:
      DoctorIssue(
        severity: .error,
        credential: credential,
        state: state,
        locations: locations,
        message: "credential is expired",
        action: "rotate or remove the credential"
      )
    case .duplicate:
      DoctorIssue(
        severity: .warning,
        credential: credential,
        state: state,
        locations: locations,
        message: "multiple entries appear to represent the same credential",
        action: "choose the authoritative item and remove the duplicate reference"
      )
    }
  }

  private func locations(
    for node: InventoryNode,
    in graph: InventoryGraph
  ) -> [CredentialLocation] {
    graph.outgoingEdges(from: node).compactMap { edge in
      switch edge.kind {
      case .storedIn, .observedIn:
        location(from: edge.to)
      case .hasState:
        nil
      }
    }
  }

  private func location(from node: InventoryNode) -> CredentialLocation? {
    if case .location(let location) = node {
      location
    } else {
      nil
    }
  }
}
