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

  public func outgoingEdges(from node: InventoryNode) -> [InventoryEdge] {
    edges.filter { $0.from == node }
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
}
