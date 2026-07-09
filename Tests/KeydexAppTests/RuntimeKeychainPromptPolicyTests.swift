import Testing
@testable import KeydexApp

@Test
func runtimeKeychainPromptRequiresPromptSettingAndEnabledKeychainSource() {
  var config = sampleSettingsData()
  config.requestPrompt = true
  config.keychainAccess = true
  config.scanSources = config.scanSources.map { source in
    var nextSource = source
    nextSource.enabled = source.persistenceID == runtimeKeychainSourceID
    return nextSource
  }

  #expect(shouldPromptBeforeLiveKeychainScan(config))
}

@Test
func runtimeKeychainPromptSkipsWhenPromptSettingIsOff() {
  var config = sampleSettingsData()
  config.requestPrompt = false
  config.keychainAccess = true

  #expect(shouldPromptBeforeLiveKeychainScan(config) == false)
}

@Test
func runtimeKeychainPromptSkipsWhenKeychainAccessIsOff() {
  var config = sampleSettingsData()
  config.requestPrompt = true
  config.keychainAccess = false

  #expect(shouldPromptBeforeLiveKeychainScan(config) == false)
  #expect(runtimeRequest(from: config).enabledSourceIDs.contains(runtimeKeychainSourceID) == false)
}

@Test
func runtimeKeychainPromptSkipsWhenKeychainSourceIsDisabled() {
  var config = sampleSettingsData()
  config.requestPrompt = true
  config.keychainAccess = true
  config.scanSources = config.scanSources.map { source in
    var nextSource = source
    if source.persistenceID == runtimeKeychainSourceID {
      nextSource.enabled = false
    }
    return nextSource
  }

  #expect(shouldPromptBeforeLiveKeychainScan(config) == false)
  #expect(runtimeRequest(from: config).enabledSourceIDs.contains(runtimeKeychainSourceID) == false)
}
