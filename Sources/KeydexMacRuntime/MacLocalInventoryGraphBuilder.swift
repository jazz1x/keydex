import Foundation
import KeydexCore
import KeydexKeychain
import KeydexRuntime

public struct MacLocalInventoryGraphBuilder: Sendable {
  private let inventoryReferences: @Sendable () throws -> [KeychainItemReference]
  private let graphBuilder: LocalInventoryGraphBuilder

  public init(
    inventoryReferences: @escaping @Sendable () throws -> [KeychainItemReference] = {
      try MacOSKeychain().inventoryReferences()
    },
    graphBuilder: LocalInventoryGraphBuilder = LocalInventoryGraphBuilder()
  ) {
    self.inventoryReferences = inventoryReferences
    self.graphBuilder = graphBuilder
  }

  public func graph(for request: LocalInventoryGraphRequest) async throws -> InventoryGraph {
    try await graphBuilder.graph(for: requestIncludingLiveKeychainObservations(request))
  }

  private func requestIncludingLiveKeychainObservations(
    _ request: LocalInventoryGraphRequest
  ) throws -> LocalInventoryGraphRequest {
    guard request.enabledSourceIDs.contains(LocalInventorySourceID.keychain) else {
      return request
    }

    let liveObservations = KeychainInventoryScanner().observations(from: try inventoryReferences())

    return LocalInventoryGraphRequest(
      metadataURL: request.metadataURL,
      enabledSourceIDs: request.enabledSourceIDs,
      scanPathValues: request.scanPathValues,
      keychainReferenceValues: request.keychainReferenceValues,
      ignoredSourceValues: request.ignoredSourceValues,
      unmanagedSourceValues: request.unmanagedSourceValues,
      environment: request.environment,
      keychainObservations: request.keychainObservations + liveObservations,
      reconcilesKeychainReferences: true,
      currentDate: request.currentDate
    )
  }
}
