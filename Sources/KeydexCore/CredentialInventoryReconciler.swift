public struct CredentialInventoryReconciler: Sendable {
  public init() {}

  public func graph(
    metadataRecords: [CredentialRecord],
    keychainObservations: [CredentialObservation]
  ) -> InventoryGraph {
    graph(
      metadataRecords: metadataRecords,
      keychainObservations: keychainObservations,
      additionalObservations: []
    )
  }

  public func graph(
    metadataRecords: [CredentialRecord],
    keychainObservations: [CredentialObservation],
    additionalObservations: [CredentialObservation]
  ) -> InventoryGraph {
    var adjustedRecords: [CredentialRecord] = []
    var adjustedObservations: [CredentialObservation] = []
    let observedKeychainIdentities = Set(keychainObservations.compactMap(Self.keychainIdentity))
    var matchedKeychainIdentities = Set<KeychainIdentity>()

    for record in metadataRecords {
      let keychainLocations = record.locations.compactMap(Self.keychainLocation)
      let nonKeychainLocations = record.locations.filter { location in
        Self.keychainLocation(location) == nil
      }

      if keychainLocations.isEmpty {
        adjustedRecords.append(record)
      } else if !nonKeychainLocations.isEmpty {
        adjustedRecords.append(
          CredentialRecord(
            ref: record.ref,
            state: record.state,
            locations: nonKeychainLocations
          )
        )
      }

      for location in keychainLocations {
        let identity = KeychainIdentity(ref: record.ref, location: location)
        let state: CredentialState
        if observedKeychainIdentities.contains(identity) {
          matchedKeychainIdentities.insert(identity)
          state = .registered
        } else {
          state = .missingKeychainItem
        }

        adjustedObservations.append(
          CredentialObservation(
            ref: record.ref,
            state: state,
            location: location
          )
        )
      }
    }

    for observation in keychainObservations {
      guard let identity = Self.keychainIdentity(observation) else {
        continue
      }

      if !matchedKeychainIdentities.contains(identity) {
        adjustedObservations.append(
          CredentialObservation(
            ref: observation.ref,
            state: .orphan,
            location: observation.location
          )
        )
      }
    }

    return InventoryGraph(
      records: adjustedRecords,
      observations: adjustedObservations + additionalObservations
    )
  }

  private static func keychainIdentity(_ observation: CredentialObservation) -> KeychainIdentity? {
    guard let location = keychainLocation(observation.location) else {
      return nil
    }

    return KeychainIdentity(ref: observation.ref, location: location)
  }

  private static func keychainLocation(_ location: CredentialLocation) -> CredentialLocation? {
    if case .keychain = location {
      location
    } else {
      nil
    }
  }
}

private struct KeychainIdentity: Equatable, Hashable, Sendable {
  let ref: CredentialRef
  let location: CredentialLocation
}
