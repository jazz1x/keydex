import KeydexCore
import Testing

@Test
func nonEmptyTextTrimsInput() throws {
  let text = try NonEmptyText.parse("  openai  ", field: "service")

  #expect(text.value == "openai")
}

@Test
func nonEmptyTextRejectsBlankInput() {
  #expect(throws: KeydexError.emptyField("service")) {
    try NonEmptyText.parse("   ", field: "service")
  }
}

@Test
func credentialStateRawValuesAreStableCliLabels() {
  #expect(CredentialState.plaintextFallback.rawValue == "plaintext-fallback")
  #expect(CredentialState.missingKeychainItem.rawValue == "missing-keychain-item")
}
