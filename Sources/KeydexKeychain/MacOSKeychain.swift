import Foundation
import KeydexCore
import Security

public struct KeychainItemReference: Equatable, Hashable, Sendable {
  public let ref: CredentialRef

  public init(service: String, account: String) throws {
    self.ref = try CredentialRef.parse(service: service, account: account)
  }
}

public struct KeychainInventoryScanner: Sendable {
  public init() {}

  public func observations(from references: [KeychainItemReference]) -> [CredentialObservation] {
    references.sorted(by: referenceSort).map { reference in
      CredentialObservation(
        ref: reference.ref,
        state: .orphan,
        location: .keychain(
          service: reference.ref.service,
          account: reference.ref.account
        )
      )
    }
  }

  private func referenceSort(
    _ left: KeychainItemReference,
    _ right: KeychainItemReference
  ) -> Bool {
    if left.ref.service.value == right.ref.service.value {
      left.ref.account.value < right.ref.account.value
    } else {
      left.ref.service.value < right.ref.service.value
    }
  }
}

public struct MacOSKeychain: Sendable {
  public init() {}

  public func inventoryReferences() throws -> [KeychainItemReference] {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecMatchLimit as String: kSecMatchLimitAll,
      kSecReturnAttributes as String: kCFBooleanTrue as Any,
    ]

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status == errSecItemNotFound {
      return []
    }

    guard status == errSecSuccess else {
      throw KeydexError.keychainQueryFailed(status)
    }

    guard let items = result as? [[String: Any]] else {
      throw KeydexError.invalidKeychainQueryResult("generic password attributes")
    }

    return try items.map(Self.reference(from:)).sorted(by: referenceSort)
  }

  public func readGenericPassword(ref _: CredentialRef) throws -> Data {
    throw KeydexError.unsupportedOperation("Keychain read")
  }

  private static func reference(from attributes: [String: Any]) throws -> KeychainItemReference {
    guard let service = attributes[kSecAttrService as String] as? String else {
      throw KeydexError.invalidKeychainAttribute("service")
    }

    guard let account = attributes[kSecAttrAccount as String] as? String else {
      throw KeydexError.invalidKeychainAttribute("account")
    }

    return try KeychainItemReference(service: service, account: account)
  }

  private func referenceSort(
    _ left: KeychainItemReference,
    _ right: KeychainItemReference
  ) -> Bool {
    if left.ref.service.value == right.ref.service.value {
      left.ref.account.value < right.ref.account.value
    } else {
      left.ref.service.value < right.ref.service.value
    }
  }
}
