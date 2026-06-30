public enum InventoryNode: Equatable, Hashable, Sendable {
  case credential(CredentialRef)
  case location(CredentialLocation)
  case state(CredentialState)
}

public enum InventoryEdgeKind: String, Equatable, Hashable, Sendable {
  case storedIn = "stored-in"
  case observedIn = "observed-in"
  case hasState = "has-state"
}

public struct InventoryEdge: Equatable, Hashable, Sendable {
  public let from: InventoryNode
  public let to: InventoryNode
  public let kind: InventoryEdgeKind

  public init(from: InventoryNode, to: InventoryNode, kind: InventoryEdgeKind) {
    self.from = from
    self.to = to
    self.kind = kind
  }
}

public struct InventoryGraphSummary: Equatable, Sendable {
  public let credentialCount: Int
  public let locationCount: Int
  public let stateCount: Int
  public let edgeCount: Int

  public init(credentialCount: Int, locationCount: Int, stateCount: Int, edgeCount: Int) {
    self.credentialCount = credentialCount
    self.locationCount = locationCount
    self.stateCount = stateCount
    self.edgeCount = edgeCount
  }
}

public struct CredentialProjection: Equatable, Sendable {
  public let ref: CredentialRef
  public let states: [CredentialState]
  public let locations: [CredentialLocation]

  public init(
    ref: CredentialRef,
    states: [CredentialState],
    locations: [CredentialLocation]
  ) {
    self.ref = ref
    self.states = states
    self.locations = locations
  }
}

public struct InventoryGraph: Equatable, Sendable {
  public let nodes: Set<InventoryNode>
  public let edges: [InventoryEdge]

  public init(observations: [CredentialObservation]) {
    var nodes = Set<InventoryNode>()
    var edges: [InventoryEdge] = []

    for observation in observations {
      Self.insert(
        ref: observation.ref,
        state: observation.state,
        locations: [observation.location],
        nodes: &nodes,
        edges: &edges
      )
    }

    self.nodes = nodes
    self.edges = edges
  }

  public init(records: [CredentialRecord]) {
    var nodes = Set<InventoryNode>()
    var edges: [InventoryEdge] = []

    for record in records {
      Self.insert(
        ref: record.ref,
        state: record.state,
        locations: record.locations,
        nodes: &nodes,
        edges: &edges
      )
    }

    self.nodes = nodes
    self.edges = edges
  }

  public init(records: [CredentialRecord], observations: [CredentialObservation]) {
    var nodes = Set<InventoryNode>()
    var edges: [InventoryEdge] = []

    for record in records {
      Self.insert(
        ref: record.ref,
        state: record.state,
        locations: record.locations,
        nodes: &nodes,
        edges: &edges
      )
    }

    for observation in observations {
      Self.insert(
        ref: observation.ref,
        state: observation.state,
        locations: [observation.location],
        nodes: &nodes,
        edges: &edges
      )
    }

    self.nodes = nodes
    self.edges = edges
  }

  public func outgoingEdges(from node: InventoryNode) -> [InventoryEdge] {
    edges.filter { $0.from == node }
  }

  public var summary: InventoryGraphSummary {
    var credentialCount = 0
    var locationCount = 0
    var stateCount = 0

    for node in nodes {
      switch node {
      case .credential:
        credentialCount += 1
      case .location:
        locationCount += 1
      case .state:
        stateCount += 1
      }
    }

    return InventoryGraphSummary(
      credentialCount: credentialCount,
      locationCount: locationCount,
      stateCount: stateCount,
      edgeCount: edges.count
    )
  }

  public var credentialProjections: [CredentialProjection] {
    let refs = nodes.compactMap { node in
      if case .credential(let ref) = node {
        ref
      } else {
        nil
      }
    }

    return refs.sorted(by: credentialSort).map { ref in
      let node = InventoryNode.credential(ref)
      return CredentialProjection(
        ref: ref,
        states: states(for: node),
        locations: locations(for: node)
      )
    }
  }

  public func credentialProjections(service: NonEmptyText) -> [CredentialProjection] {
    credentialProjections.filter { projection in
      projection.ref.service == service
    }
  }

  private static func insert(
    ref: CredentialRef,
    state: CredentialState,
    locations: [CredentialLocation],
    nodes: inout Set<InventoryNode>,
    edges: inout [InventoryEdge]
  ) {
    let credentialNode = InventoryNode.credential(ref)
    let stateNode = InventoryNode.state(state)

    nodes.insert(credentialNode)
    nodes.insert(stateNode)
    append(InventoryEdge(from: credentialNode, to: stateNode, kind: .hasState), to: &edges)

    for location in locations {
      let locationNode = InventoryNode.location(location)
      nodes.insert(locationNode)
      append(
        InventoryEdge(
          from: credentialNode,
          to: locationNode,
          kind: edgeKind(for: location)
        ),
        to: &edges
      )
    }
  }

  private static func append(_ edge: InventoryEdge, to edges: inout [InventoryEdge]) {
    if !edges.contains(edge) {
      edges.append(edge)
    }
  }

  private static func edgeKind(for location: CredentialLocation) -> InventoryEdgeKind {
    switch location {
    case .keychain:
      .storedIn
    case .environment, .shellProfile, .configFile:
      .observedIn
    }
  }

  private func states(for node: InventoryNode) -> [CredentialState] {
    outgoingEdges(from: node).compactMap { edge in
      if edge.kind == .hasState, case .state(let state) = edge.to {
        state
      } else {
        nil
      }
    }
  }

  private func locations(for node: InventoryNode) -> [CredentialLocation] {
    outgoingEdges(from: node).compactMap { edge in
      switch edge.kind {
      case .storedIn, .observedIn:
        if case .location(let location) = edge.to {
          location
        } else {
          nil
        }
      case .hasState:
        nil
      }
    }
  }

  private func credentialSort(_ left: CredentialRef, _ right: CredentialRef) -> Bool {
    if left.service.value == right.service.value {
      left.account.value < right.account.value
    } else {
      left.service.value < right.service.value
    }
  }
}
