import Foundation
import KeydexRuntime

let runtimeKeychainSourceID = LocalInventorySourceID.keychain

func runtimeRequest(from config: ShellSettingsConfig) -> LocalInventoryGraphRequest {
  var enabledSourceIDs = Set(
    config.scanSources.filter(\.enabled).map(\.persistenceID)
  )
  if !config.keychainAccess {
    enabledSourceIDs.remove(runtimeKeychainSourceID)
  }

  return LocalInventoryGraphRequest(
    enabledSourceIDs: enabledSourceIDs,
    scanPathValues: config.scanPaths.map(\.value),
    keychainReferenceValues: config.keychainReferences.map(\.value),
    ignoredSourceValues: Set(config.ignoredSources.map(\.value)),
    unmanagedSourceValues: Set(config.unmanagedSources.map(\.value)),
    environment: ProcessInfo.processInfo.environment,
    reconcilesKeychainReferences: true
  )
}

func shouldPromptBeforeLiveKeychainScan(_ config: ShellSettingsConfig) -> Bool {
  config.requestPrompt
    && runtimeRequest(from: config).enabledSourceIDs.contains(runtimeKeychainSourceID)
}
