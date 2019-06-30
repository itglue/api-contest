//
//  ContactAttributes.swift
//  ITGlueContacts
//
//  Created by Michael Page on 15/5/19.
//

import Foundation

struct ContactAttributes: Codable {
    var organizationName: String
    var jobTitle: String?
    var firstName: String?
    var lastName: String?
    var fullName: String {
        return [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }

    var contactEmails: [Email]
    var contactPhones: [Phone]
    var notes: String?
    private var locationIDInt: Int?
    var locationID: String? {
        get {
            if let locationIDInt = locationIDInt {
                return String(locationIDInt)
            }
            return nil
        }
        set {
            if let newValue = newValue {
                locationIDInt = Int(newValue)
            } else {
                locationIDInt = nil
            }
        }
    }

    var location: Location?
    var resourceURL: String?
    var organizationNameAndLocationName: String?

    private enum CodingKeys: String, CodingKey {
        case organizationName = "organization-name"
        case jobTitle = "title"
        case firstName = "first-name"
        case lastName = "last-name"
        case contactEmails = "contact-emails"
        case contactPhones = "contact-phones"
        case notes
        case locationIDInt = "location-id"
        case location
        case resourceURL = "resource-url"
    }

    init(organizationName: String, jobTitle: String?, firstName: String?, lastName: String?, contactEmails: [Email], contactPhones: [Phone], notes: String?, locationID: String?, location: Location?, resourceURL: String?) {
        self.organizationName = organizationName
        self.jobTitle = jobTitle
        self.firstName = firstName
        self.lastName = lastName
        self.contactEmails = contactEmails
        self.contactPhones = contactPhones
        self.notes = notes
        self.locationID = locationID
        self.location = location
        self.resourceURL = resourceURL
    }
}
