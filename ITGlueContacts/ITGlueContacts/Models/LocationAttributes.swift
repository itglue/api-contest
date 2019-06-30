//
//  LocationAttributes.swift
//  ITGlueContacts
//
//  Created by Michael Page on 15/5/19.
//

import Foundation

struct LocationAttributes: Codable {
    var id: Int
    var organizationName: String
    var organizationLocationName: String?
    var organizationNameAndLocationName: String? {
        // Ensure organization location name is set.
        guard let organizationLocationName = organizationLocationName else {
            return nil
        }
        // Append location to end of organization name (e.g. "Tesla - Gigafactory").
        return "\(organizationName) - \(organizationLocationName)"
    }

    var address1: String?
    var address2: String?
    var city: String?
    var region: String?
    var postalCode: String?
    var country: String?
    var phone: String?
    var notes: String?
    var resourceURL: String?

    private enum CodingKeys: String, CodingKey {
        case id = "organization-id"
        case organizationName = "organization-name"
        case organizationLocationName = "name"
        case address1 = "address-1"
        case address2 = "address-2"
        case city
        case region = "region-name"
        case postalCode = "postal-code"
        case country = "country-name"
        case phone
        case notes
        case resourceURL = "resource-url"
    }

    init(id: Int, organizationName: String, organizationLocationName: String?, address1: String?, address2: String?, city: String?, region: String?, postalCode: String?, country: String?, phone: String?, notes: String?, resourceURL: String?) {
        self.id = id
        self.organizationName = organizationName
        self.organizationLocationName = organizationLocationName
        self.address1 = address1
        self.address2 = address2
        self.city = city
        self.region = region
        self.postalCode = postalCode
        self.country = country
        self.phone = phone
        self.notes = notes
        self.resourceURL = resourceURL
    }
}
