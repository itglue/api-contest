//
//  Contact.swift
//  ITGlueContacts
//
//  Created by Michael Page on 15/5/19.
//

import Contacts
import Foundation

struct Contact: Codable {
    let id: String
    var attributes: ContactAttributes
}

extension Contact {
    var isAnOrganizationLocation: Bool {
        // If contact has neither a first or last name, it is an organization.
        return attributes.firstName == nil && attributes.lastName == nil
    }

    var contactType: CNContactType {
        return isAnOrganizationLocation ? .organization : .person
    }
}

extension Contact: Comparable {
    // Required for contact sorting.
    static func < (lhs: Contact, rhs: Contact) -> Bool {
        let lhsName = lhs.isAnOrganizationLocation ? lhs.attributes.organizationName : lhs.attributes.fullName
        let rhsName = rhs.isAnOrganizationLocation ? rhs.attributes.organizationName : rhs.attributes.fullName
        // Lowercased to allow for fair comparison of names with capitalization.
        return lhsName.lowercased() < rhsName.lowercased()
    }

    static func == (lhs: Contact, rhs: Contact) -> Bool {
        let lhsName = lhs.isAnOrganizationLocation ? lhs.attributes.organizationName : lhs.attributes.fullName
        let rhsName = rhs.isAnOrganizationLocation ? rhs.attributes.organizationName : rhs.attributes.fullName
        return lhsName == rhsName
    }
}

extension Contact {
    var cnContactValue: CNContact {
        // Create a mutable contact.
        let contact = CNMutableContact()

        // Set contact attributes.
        contact.givenName = attributes.firstName ?? ""
        contact.familyName = attributes.lastName ?? ""
        contact.jobTitle = attributes.jobTitle ?? ""
        contact.organizationName = attributes.organizationName

        // For each phone number.
        for phone in attributes.contactPhones {
            // Ensure phone number is not nil.
            guard let cnLabeledValue = phone.cnLabeledValue else {
                continue
            }
            // Add phone number to contact.
            contact.phoneNumbers.append(cnLabeledValue)
        }

        // For each email address.
        for email in attributes.contactEmails {
            // Ensure email address is not nil.
            guard let cnLabeledValue = email.cnLabeledValue else {
                continue
            }
            // Add email address to contact.
            contact.emailAddresses.append(cnLabeledValue)
        }

        // Set work address.
        if let postalAddress = attributes.location?.cnLabeledValue {
            contact.postalAddresses = [postalAddress]
        }

        contact.note = attributes.notes ?? ""

        // Set IT Glue rosource URL.
        if let resourceURL = attributes.resourceURL {
            let cnLabeledValue = CNLabeledValue(label: "IT Glue", value: resourceURL as NSString)
            contact.urlAddresses = [cnLabeledValue]
        }

        // Return contact.
        return contact.copy() as! CNContact
    }

    // Initializer for creating a contact object from an existing iOS contact.
    init(contact: CNContact) {
        id = contact.identifier

        var contactEmails = [Email]()
        for contactEmailAddress in contact.emailAddresses {
            let email = Email(address: contactEmailAddress.value as String, label: contactEmailAddress.label)
            contactEmails.append(email)
        }

        var contactPhones = [Phone]()
        for contactPhone in contact.phoneNumbers {
            // Extension numbers are stored after a phone number and are seperated by a comma.
            let phoneNumberComponents = contactPhone.value.stringValue.components(separatedBy: ",")
            guard let phoneNumber = phoneNumberComponents.first else {
                continue
            }
            let phone = Phone(number: phoneNumber, extensionNumber: phoneNumberComponents[1], label: contactPhone.label)
            contactPhones.append(phone)
        }

        var resourceURL: String?
        if let firstURL = contact.urlAddresses.first?.value as String? {
            resourceURL = firstURL
        }

        attributes = ContactAttributes(organizationName: contact.organizationName, jobTitle: contact.jobTitle, firstName: contact.givenName, lastName: contact.familyName, contactEmails: contactEmails, contactPhones: contactPhones, notes: contact.note, locationID: nil, location: nil, resourceURL: resourceURL)
    }

    // Initializer for creating a contact object from an organization's location (e.g. "Tesla - Gigafactory").
    init(location: Location) {
        id = location.id

        var contactPhones = [Phone]()

        if let phoneNumber = location.attributes.phone {
            let phone = Phone(number: phoneNumber, extensionNumber: nil, label: Label.main.rawValue)
            contactPhones.append(phone)
        }

        // Sets orgnization location contacts name to "Tesla - Gigafactory", with the fallback to "Tesla".
        let name = location.attributes.organizationNameAndLocationName ?? location.attributes.organizationName

        // Set attributes.
        attributes = ContactAttributes(organizationName: name, jobTitle: nil, firstName: nil, lastName: nil, contactEmails: [], contactPhones: contactPhones, notes: location.attributes.notes, locationID: location.id, location: location, resourceURL: location.attributes.resourceURL)
    }
}
