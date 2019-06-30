//
//  KeychainItem.swift
//  ITGlueContacts
//
//  Created by Michael Page on 19/6/19.
//

import Foundation

// Keychain error cases.
enum KeychainError: Error {
    case missingKeychainItem, badKeychainItemData, unknownError
}

struct KeychainItem {
    // Service identifier for storing items (secrets) in the Keychain.
    let service = "ITGlueContactsService"

    // Formulate a Keychain query with required attributes.
    private func keychainQuery(service: String) -> [String: AnyObject] {
        var query: [String: AnyObject] = [:]

        // Set service associated with the Keychain item.
        query[kSecAttrService as String] = service as AnyObject

        // Set the Keychain item class to generic password.
        query[kSecClass as String] = kSecClassGenericPassword

        return query
    }

    func read() throws -> String {
        // Search for an existing Keychain item.
        var query = keychainQuery(service: service)

        // Return only a single match.
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        // Include the attributes of the Keychain item.
        query[kSecReturnAttributes as String] = kCFBooleanTrue

        // Include the data of the Keychain item.
        query[kSecReturnData as String] = kCFBooleanTrue

        // A variable for storing the query result (Keychain item).
        var queryResult: AnyObject?

        // Attempt to extract Keychain item and store the result in queryResult.
        let queryStatus = SecItemCopyMatching(query as CFDictionary, &queryResult)

        // Ensure a Keychain item was found.
        guard queryStatus != errSecItemNotFound else {
            throw KeychainError.missingKeychainItem
        }

        // Ensure query status does not contain any other error.
        guard queryStatus == noErr else {
            throw KeychainError.unknownError
        }

        // Extract the password from query result.
        guard let existingItem = queryResult as? [String: AnyObject], let keychainItemData = existingItem[kSecValueData as String] as? Data, let password = String(data: keychainItemData, encoding: .utf8) else {
            // Keychain item data was malformed.
            throw KeychainError.badKeychainItemData
        }

        return password
    }

    func write(_ password: String) throws {
        // Encode the provided password.
        let keychainItemData = password.data(using: .utf8)

        // Create a Keychain query.
        var query = keychainQuery(service: service)

        do {
            // Test if a Keychain item for this service already exists.
            try _ = read()

            // A Keychain item for this service already exists.
            // Set the Keychain item data.
            var attributesToUpdate: [String: AnyObject] = [:]
            attributesToUpdate[kSecValueData as String] = keychainItemData as AnyObject?

            // Execute the query to update an existing item in the Keychain.
            let queryStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

            // Ensure query status did not contain an error.
            guard queryStatus == noErr else {
                throw KeychainError.unknownError
            }
        } catch KeychainError.missingKeychainItem {
            // A Keychain item for this service does not currently exist.
            // Set the Keychain item data.
            query[kSecValueData as String] = keychainItemData as AnyObject?

            // Execute the query to save a new item to Keychain.
            let queryStatus = SecItemAdd(query as CFDictionary, nil)

            // Ensure query status did not contain an error.
            guard queryStatus == noErr else {
                throw KeychainError.unknownError
            }
        }
    }
}
