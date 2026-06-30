import Foundation
import KeydexCore
import Security

public struct MacOSKeychain: Sendable {
  public init() {}

  public func readGenericPassword(ref _: CredentialRef) throws -> Data {
    throw KeydexError.unsupportedOperation("Keychain read")
  }
}
