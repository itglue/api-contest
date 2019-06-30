//
//  DataSource.swift
//  ITGlueContacts
//
//  Created by Michael Page on 15/5/19.
//

import Foundation

enum DataSourceError: Error {
    case invalidData, networkIssue
}

enum DataSourceTaskStatus {
    case complete
}

class DataSource {
    static let shared = DataSource()

    var lastUpdateTimestamp: Date? {
        didSet {
            populateAllContactsDictionary()
        }
    }

    // Regular contacts (people).
    var regularContacts = [Contact]()
    // Contacts generated from an organization's location data.
    var organizationLocationContacts = [Contact]()
    // Both regular & organization location contacts.
    var allContacts: [Contact] {
        return regularContacts + organizationLocationContacts
    }

    var locations = [Location]()
    // Stores a dictionary of contacts under associated character index, concept similar to: ["A": ["Alice", "Anna"], "C": ["Carla"]]
    var allContactsDictionary = [String: [Contact]]()
    var allContactsSections: [String] {
        var sorted = Array(allContactsDictionary.keys).sorted()
        let numbersIndex = sorted.firstIndex(of: "#")
        let numbersArray = sorted.remove(at: numbersIndex!)
        sorted.append(numbersArray)
        return sorted
    }

    func populateAllContactsDictionary() {
        let defaultIndex: [String: [Contact]] = ["A": [], "B": [], "C": [], "D": [], "E": [], "F": [], "G": [], "H": [], "I": [], "J": [], "K": [], "L": [], "M": [], "N": [], "O": [], "P": [], "Q": [], "R": [], "S": [], "T": [], "U": [], "V": [], "W": [], "X": [], "Y": [], "Z": [], "#": []]

        // Clear out existing all contacts dictionary.
        allContactsDictionary = defaultIndex

        // Loop through each contact.
        allContacts.forEach { contact in
            var firstCharacter = String()
            if contact.isAnOrganizationLocation {
                // Get first character of organization name.
                firstCharacter = String(contact.attributes.organizationName.prefix(1)).uppercased()
            } else {
                // Get first character of full name.
                firstCharacter = String(contact.attributes.fullName.prefix(1)).uppercased()
            }

            if firstCharacter.rangeOfCharacter(from: .letters) != nil {
                // If a dictionary index already exists for that character.
                if allContactsDictionary[firstCharacter] != nil {
                    // Add contact under existing associated character index.
                    allContactsDictionary[firstCharacter]?.append(contact)
                } else {
                    // Add contact under new associated character index.
                    allContactsDictionary[firstCharacter] = [contact]
                }
            } else {
                // If first character is numeric or not a letter add it to # index.
                allContactsDictionary["#"]?.append(contact)
            }
        }

        // Sort contact arrays by name.
        for (character, contacts) in allContactsDictionary {
            allContactsDictionary[character] = contacts.sorted()
        }
    }

    // Needed for adding work addresses to contacts.
    func appendLocationsToContacts() {
        // Create an empty array of contacts.
        var updatedContacts = [Contact]()

        // Loop through each regular contact.
        for contact in regularContacts {
            // Create a mutable copy of the contact.
            var updatedContact = contact

            // Search for a location that matches the contact's location ID. Copy the location data from that match to the contact's location value. This is needed to set the contact's work address.
            updatedContact.attributes.location = locations.first(where: { $0.id == contact.attributes.locationID })

            // Add the updated contact to the updated contacts array.
            updatedContacts.append(updatedContact)
        }

        // Update the regularContacts array with contacts that may now contain work addresses.
        regularContacts = updatedContacts
    }

    // Function loops through organization locations and creates an organization contact for each location.
    func createOrganizationLocationContacts() {
        // Create an empty array of organization location contacts.
        var organizationLocationContacts = [Contact]()

        // Loop through each location.
        for location in locations {
            // Create a contact based on that location.
            let organizationLocationContact = Contact(location: location)
            // Add the contact to the organization location contacts array.
            organizationLocationContacts.append(organizationLocationContact)
        }

        // Update the self.organizationLocationContacts with the new contacts array.
        self.organizationLocationContacts = organizationLocationContacts
    }

    // Function updates self.locations and self.regularContacts from IT Glue API.
    func updateData(completionHandler: @escaping (Result<DataSourceTaskStatus, DataSourceError>) -> Void) {
        // Get all organization locations from IT Glue API.
        ITGlueAPI().getITGlueData(.locations) { result in

            switch result {
            case let .success(resultTuple):
                let (_, locations) = resultTuple
                if locations != nil {
                    // Update self.locations with IT Glue provided locations.
                    self.locations = locations!
                    self.createOrganizationLocationContacts()
                }

                // Get all contacts (regardless of organization) from IT Glue API.
                ITGlueAPI().getITGlueData(.contacts) { result in
                    switch result {
                    case let .success(resultTuple):
                        let (contacts, _) = resultTuple
                        if contacts != nil {
                            // Update self.regularContacts with IT Glue provided contacts.
                            self.regularContacts = contacts!
                            self.appendLocationsToContacts()
                            self.lastUpdateTimestamp = Date()
                        }
                        // Notify function caller that locations and contacts have finished updating.
                        completionHandler(Result.success(.complete))
                    case let .failure(error):
                        print(error.localizedDescription)
                        switch error {
                        case .invalidData:
                            completionHandler(.failure(.invalidData))
                        case .networkIssue:
                            completionHandler(.failure(.networkIssue))
                        }
                    }
                }

            case let .failure(error):
                print(error.localizedDescription)
                switch error {
                case .invalidData:
                    completionHandler(.failure(.invalidData))
                case .networkIssue:
                    completionHandler(.failure(.networkIssue))
                }
            }
        }
    }
}
