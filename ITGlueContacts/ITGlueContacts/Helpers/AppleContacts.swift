//
//  AppleContacts.swift
//  ITGlueContacts
//
//  Created by Michael Page on 17/5/19.
//

import Contacts
import Foundation

enum AppleContactsError: Error {
    case missingRequiredContainer, unableToIdentifyContainer, unableToSearchContainers, unsupportedContactsContainer, unableToAddGroup, unableToSearchGroups, missingRequiredGroup, unableToAddContact, unableToSearchContacts, unableToUpdateExistingContact
}

enum AppleContactsTaskStatus {
    case complete
}

class AppleContacts {
    private let contactStore = CNContactStore()
    // Regular contact groups are used with CardDAV and local accounts.
    private let groupName = "IT Glue"
    // Whereas containers are used as groups with Exchange accounts.
    private var containerName: String {
        return groupName
    }

    // Main function, goes through each contact and adds it to Apple Contacts.
    func importAllITGlueContacts(completionHandler: @escaping (Result<AppleContactsTaskStatus, AppleContactsError>) -> Void) throws {
        for contact in DataSource.shared.allContacts {
            do {
                try addOrUpdateITGlueContact(contact)
            } catch let error as AppleContactsError {
                completionHandler(.failure(error))
            }
        }
        completionHandler(.success(.complete))
    }

    // Adds or updates a single contact to Apple Contacts.
    func addOrUpdateITGlueContact(_ itGlueContact: Contact) throws {
        guard let existingAppleContactsContact = try returnExistingContact(itGlueContact) else {
            // IT Glue Contact does not currently exist in Contacts. Create a new contact.
            try addContact(itGlueContact)
            return
        }
        try updateExistingContact(itGlueContact, existingAppleContactsContact: existingAppleContactsContact)
    }
}

// MARK: - Containers

extension AppleContacts {
    // Returns the Apple Contacts container set under iOS Settings > Contacts > Default Account.
    func returnDefaultContainer() throws -> CNContainer? {
        var defaultContainer: CNContainer?
        // Get the current default container identifier.
        let defaultContainerIdentifier = contactStore.defaultContainerIdentifier()
        // Create a search predicate to find the container with the default identifier.
        let predicateForMatchingContainerIdentifier = CNContainer.predicateForContainers(withIdentifiers: [defaultContainerIdentifier])
        do {
            // Search for the container.
            let matchingContainers = try contactStore.containers(matching: predicateForMatchingContainerIdentifier)
            defaultContainer = matchingContainers.first(where: { $0.identifier == defaultContainerIdentifier })
        } catch {
            print("Error: Unable to search containers.")
            throw AppleContactsError.unableToSearchContainers
        }
        return defaultContainer
    }

    // Returns the default container type (CardDAV, Exchange, local or unassigned).
    func defaultContainerType() -> CNContainerType {
        var defaultContainer: CNContainer?
        do {
            defaultContainer = try returnDefaultContainer()
        } catch {
            print("Error: Unable to find default contacts container!")
        }
        return defaultContainer?.type ?? CNContainerType.unassigned
    }

    // Unlike CardDAV which creates an "IT Glue" group, Exchange relies on an "IT Glue" container. This function returns that container.
    func returnITGlueContainer() throws -> CNContainer? {
        var matchingContainer: CNContainer?

        // Get all existing containers.
        let allContainers = try contactStore.containers(matching: nil)
        // Find any containers that match the specified container name.
        let matchingContainers = allContainers.filter({ $0.name == containerName })
        switch matchingContainers.count {
        case 0:
            print("Error: Unable to find '\(containerName)' container!")
            throw AppleContactsError.missingRequiredContainer
        case 1:
            matchingContainer = matchingContainers.first
        default:
            print("Error: Multiple '\(containerName)' contains found.")
            throw AppleContactsError.unableToIdentifyContainer
        }

        guard matchingContainer != nil else {
            print("Warning: Unable to find an existing container for: \(containerName).")
            return nil
        }

        return matchingContainer
    }

    // Returns the container that a contact belongs to.
    func returnContactContainer(_ contact: CNContact) throws -> CNContainer? {
        var contactContainer: CNContainer?
        let predicateForMatchingContainerIdentifier = CNContainer.predicateForContainerOfContact(withIdentifier: contact.identifier)
        do {
            let matchingContainers = try contactStore.containers(matching: predicateForMatchingContainerIdentifier)
            contactContainer = matchingContainers.first
        } catch {
            print("Error: Unable to search containers.")
            throw AppleContactsError.unableToSearchContainers
        }
        return contactContainer
    }
}

// MARK: - Groups

extension AppleContacts {
    // Creates a new Apple Contacts group with the provided group name.
    func addGroup(_ groupName: String) throws -> CNGroup? {
        let group = CNMutableGroup()
        group.name = groupName

        let saveRequest = CNSaveRequest()

        // Add the group to the default contacts container.
        saveRequest.add(group, toContainerWithIdentifier: nil)

        do {
            // Execute save request.
            try contactStore.execute(saveRequest)
            // Return the newly created group.
            return try returnGroup(groupName)
        } catch {
            print("Error: Unable to create new group: \(error.localizedDescription)")
            throw AppleContactsError.unableToAddGroup
        }
    }

    // Returns an existing Apple Contacts group if it exists.
    func returnGroup(_ groupName: String) throws -> CNGroup? {
        var matchingGroup: CNGroup?

        do {
            // Get all existing groups.
            let allGroups = try contactStore.groups(matching: nil)
            // Find the first group that matches group name.
            matchingGroup = allGroups.first(where: { $0.name == groupName })
        } catch {
            print("Error: Unable to search Apple Contacts groups!")
            throw AppleContactsError.unableToSearchGroups
        }

        guard matchingGroup != nil else {
            print("Warning: Unable to find an existing Apple Contacts group for: \(groupName).")
            return nil
        }

        return matchingGroup
    }

    // Returns an existing contact group if it exists, otherwise it will add a new one.
    func returnExistingOrNewlyCreatedGroup(_ groupName: String) throws -> CNGroup? {
        do {
            // Check if group already exists in Apple Contacts.
            if let existingContactsGroup = try returnGroup(groupName) {
                return existingContactsGroup
            }
        } catch {
            print("Error: Unable to search Apple Contacts groups!")
            throw AppleContactsError.unableToSearchGroups
        }

        do {
            // Group does not exist in Apple Contacts, add it.
            let newContactsGroup = try addGroup(groupName)
            return newContactsGroup
        } catch {
            print("Error: Unable to create a new group named: '\(groupName)'.")
            throw AppleContactsError.unableToAddGroup
        }
    }
}

// MARK: - Contacts

extension AppleContacts {
    // Adds a new IT Glue contact into Apple Contacts.
    func addContact(_ newContact: Contact) throws {
        // Create a mutable copy of the contact (required by CNSaveRequest).
        let mutableContact = newContact.cnContactValue.mutableCopy() as! CNMutableContact

        // Create a CNSaveRequest.
        let saveRequest = CNSaveRequest()

        switch defaultContainerType() {
        case .cardDAV, .local:
            // Ensure the the specified group ("IT Glue") exists, if not create it.
            guard let contactGroup = try returnExistingOrNewlyCreatedGroup(groupName) else {
                print("Error: Unable to locate or create group (\(groupName) in Contacts!)")
                throw AppleContactsError.missingRequiredGroup
            }
            // As Exchange does not support the contact type attribute. It is only set for CardDAV and local contacts.
            mutableContact.contactType = newContact.contactType
            // Add contact to contacts.
            saveRequest.add(mutableContact, toContainerWithIdentifier: nil)
            // Add the new contact to the IT Glue contact group.
            saveRequest.addMember(mutableContact, to: contactGroup)
        case .exchange:
            guard let itGlueContainer = try returnITGlueContainer() else {
                print("Error: Unable to locate a (\(containerName) container in Contacts!)")
                throw AppleContactsError.missingRequiredContainer
            }
            // Add contact to contacts in the Exchange 'IT Glue' container.
            saveRequest.add(mutableContact, toContainerWithIdentifier: itGlueContainer.identifier)
        default:
            print("Error: Unsupported contacts container detected.")
            throw AppleContactsError.unsupportedContactsContainer
        }

        do {
            // Execute save request.
            try contactStore.execute(saveRequest)
        } catch {
            print("Error: Adding contact: \(error.localizedDescription)")
            throw AppleContactsError.unableToAddContact
        }
    }

    // Searches Apple Contacts for an existing contact with a matching name of the provided IT Glue Contact.
    func returnExistingContact(_ itGlueContact: Contact) throws -> CNContact? {
        // Returns the contact name, formatted with the specified formatter (default value is CNContactFormatterStyleFullName).
        let contactFormatter = CNContactFormatter()
        guard let contactName = contactFormatter.string(from: itGlueContact.cnContactValue) else {
            return nil
        }

        // Create a search predicate to find contacts with matching name.
        let predicateForMatchingName = CNContact.predicateForContacts(matchingName: contactName)

        // Contact keys (attributes) to fetch, app will crash when attempting to read data from a key that is not fetched.
        let keysToFetch = [CNContactJobTitleKey, CNContactOrganizationNameKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey, CNContactPhoneNumbersKey, CNContactNoteKey, CNContactPostalAddressesKey, CNContactUrlAddressesKey, CNContainerTypeKey, CNContactTypeKey] as [CNKeyDescriptor]

        var possibleMatchingContacts = [CNContact]()
        do {
            // Perform search.
            possibleMatchingContacts = try contactStore.unifiedContacts(matching: predicateForMatchingName, keysToFetch: keysToFetch)
        } catch {
            print("Error: Unable to search Apple Contacts!")
            throw AppleContactsError.unableToSearchContacts
        }

        var matchingContact: CNContact?
        // When searching for an organization location the search results will also include contacts of people that belong to that organization. Therefore we need to filter results differently for an organization location contact.
        if itGlueContact.isAnOrganizationLocation {
            // Find the first occurrence where first and last name are unset and the organization name matches.
            matchingContact = possibleMatchingContacts.first(where: { $0.givenName == "" && $0.familyName == "" && $0.organizationName == itGlueContact.attributes.organizationName })
        } else {
            // Check if first or last name match or if they are unset (a single named contact).
            matchingContact = possibleMatchingContacts.first(where: { ($0.givenName == itGlueContact.attributes.firstName || $0.givenName == "") && ($0.familyName == itGlueContact.attributes.lastName || $0.familyName == "") })
        }

        guard matchingContact != nil else {
            print("Warning: Was unable to find an existing contact for: \(itGlueContact.attributes.fullName) \(itGlueContact.attributes.organizationName).")
            return nil
        }

        return matchingContact
    }

    // Function updates an existing Apple Contacts contact with data from an IT Glue contact.
    func updateExistingContact(_ itGlueContact: Contact, existingAppleContactsContact: CNContact) throws {
        // Create a mutable copy of the existing contact.
        let mutableContact = existingAppleContactsContact.mutableCopy() as! CNMutableContact

        // If job title is missing or has changed.
        if let jobTitle = itGlueContact.attributes.jobTitle, mutableContact.jobTitle != jobTitle {
            // Update job title.
            mutableContact.jobTitle = jobTitle
        }

        // If organization name is missing or has changed.
        if mutableContact.organizationName != itGlueContact.attributes.organizationName {
            // Update organization name.
            mutableContact.organizationName = itGlueContact.attributes.organizationName
        }

        // Populate a string array of existing phone numbers.
        let existingPhoneNumbers = mutableContact.phoneNumbers.map({ $0.value.stringValue })

        // For each phone number provided by the IT Glue API.
        for itGlueProvidedPhoneEntry in itGlueContact.attributes.contactPhones {
            // Ensure itGlueProvidedPhoneEntry.numberAndExtensionNumber is not nil, ensure number does not already exist in the contact, ensure a cnLabeledValue can be generated from that phone number.
            guard let itGlueProvidedPhoneNumber = itGlueProvidedPhoneEntry.numberAndExtensionNumber, !existingPhoneNumbers.contains(itGlueProvidedPhoneNumber), let cnLabeledValue = itGlueProvidedPhoneEntry.cnLabeledValue else {
                // Continue to the next phone number.
                continue
            }

            // Phone number is new, add it to the contact.
            mutableContact.phoneNumbers.append(cnLabeledValue)
        }

        // Populate a string array of existing email addresses.
        let existingEmailAddresses = mutableContact.emailAddresses.map({ $0.value as String })

        // For each email address provided by the IT Glue API.
        for itGlueProvidedEmailEntry in itGlueContact.attributes.contactEmails {
            // Ensure itGlueProvidedEmailEntry.address is not nil, ensure email address does not already exist in the contact, ensure a cnLabeledValue can be generated from that email address.
            guard let itGlueProvidedEmailAddress = itGlueProvidedEmailEntry.address, !existingEmailAddresses.contains(itGlueProvidedEmailAddress), let cnLabeledValue = itGlueProvidedEmailEntry.cnLabeledValue else {
                // Continue to the next email address.
                continue
            }

            // Email address is new, add it to the contact.
            mutableContact.emailAddresses.append(cnLabeledValue)
        }

        // Boolean to track if the contact already has a work postal address.
        var workPostalAddressAlreadyPresent = false

        // Declare an empty array of postal addresses.
        var updatedPostalAddresses = [CNLabeledValue<CNPostalAddress>]()

        // For each existing postal address provided by iOS Contacts.
        for existingPostalAddress in mutableContact.postalAddresses {
            // Check if the existing postal address label is equal to "work" (or the localized equivalent), ensure the IT Glue API provided postal address can be converted into a cnLabeledValue.
            if existingPostalAddress.label == Label.work.localizedString, let workPostalAddress = itGlueContact.attributes.location?.cnLabeledValue {
                // Update boolean to signify that the contact already had a work postal address.
                workPostalAddressAlreadyPresent = true

                // Regardless of whether the work address changed, replace it with the IT Glue API provided postal address.
                updatedPostalAddresses.append(workPostalAddress)
                continue
            } else {
                // Existing postal address label did not equal "work" (or the localized equivalent), add non-work address.
                updatedPostalAddresses.append(existingPostalAddress)
            }
        }

        // If there was no postal address with label equal to "work" (or the localized equivalent).
        if !workPostalAddressAlreadyPresent {
            // Ensure the IT Glue API provided postal address can be converted into a cnLabeledValue.
            if let workPostalAddress = itGlueContact.attributes.location?.cnLabeledValue {
                // Add the postal address to the array of updated postal addresses.
                updatedPostalAddresses.append(workPostalAddress)
            }
        }

        // Update contact postal addresses.
        mutableContact.postalAddresses = updatedPostalAddresses

        // If the notes field has changed.
        if let notes = itGlueContact.attributes.notes, mutableContact.note != notes {
            // Update notes.
            mutableContact.note = notes
        }

        // Ensure an IT Glue resource URL is set. Find where the existing contact is stored (CardDAV, Exchange, local) as this impacts what data can be stored.
        if let resourceURL = itGlueContact.attributes.resourceURL, let contactContainer = try returnContactContainer(mutableContact) {
            let cnLabeledValue = CNLabeledValue(label: "IT Glue", value: resourceURL as NSString)

            // As Exchange contacts can only store a single URL and does not support the contact type attribute.
            if contactContainer.type == .exchange {
                mutableContact.urlAddresses = [cnLabeledValue]
            } else {
                // If the contact type has changed.
                if mutableContact.contactType != itGlueContact.contactType {
                    // Update contact type.
                    mutableContact.contactType = itGlueContact.contactType
                }
                
                // Boolean to track if the contact already has an IT Glue URL set.
                var itGlueURLAddressAlreadyPresent = false

                // To avoid removing non IT Glue URLs, loop through existing URLs.
                mutableContact.urlAddresses = mutableContact.urlAddresses.map({ urlAddress in
                    // If URL label is "IT Glue".
                    if urlAddress.label == "IT Glue" {
                        // Note that the IT Glue URL is already present.
                        itGlueURLAddressAlreadyPresent = true
                        // If the resource URL has changed.
                        if urlAddress.value as String != resourceURL {
                            // Return updated value.
                            return cnLabeledValue
                        }
                    }
                    // Not an IT Glue URL, return as is.
                    return urlAddress
                })

                // If no IT Glue URL was found.
                if !itGlueURLAddressAlreadyPresent {
                    // Add the IT Glue URL.
                    mutableContact.urlAddresses.append(cnLabeledValue)
                }
            }
        }

        // Create a save request.
        let saveRequest = CNSaveRequest()

        // Update exiting contact (do not create duplicate contacts).
        saveRequest.update(mutableContact)

        do {
            // Execute save request (write to disk).
            try contactStore.execute(saveRequest)
        } catch {
            print("Error: While trying to update existing contact! \(mutableContact.familyName) \(error.localizedDescription)")
            throw AppleContactsError.unableToUpdateExistingContact
        }
    }
}
