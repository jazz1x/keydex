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

  public init(records: [CredentialRecord]) {
    var nodes = Set<InventoryNode>()
    var edges: [InventoryEdge] = []

    for record in records {
      let credentialNode = InventoryNode.credential(record.ref)
      let stateNode = InventoryNode.state(record.state)

      nodes.insert(credentialNode)
      nodes.insert(stateNode)
      edges.append(InventoryEdge(from: credentialNode, to: stateNode, kind: .hasState))

      for location in record.locations {
        let locationNode = InventoryNode.location(location)
        nodes.insert(locationNode)
        edges.append(
          InventoryEdge(
            from: credentialNode,
            to: locationNode,
            kind: Self.edgeKind(for: location)
          )
        )
      }
    }

    self.nodes = nodes
    self.edges = edges
  }

  public func outgoingEdges(from node: InventoryNode) -> [InventoryEdge] {
    edges.filter { $0.from == node }
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
