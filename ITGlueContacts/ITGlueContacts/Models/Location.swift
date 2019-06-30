//
//  Location.swift
//  ITGlueContacts
//
//  Created by Michael Page on 15/5/19.
//

import Contacts
import Foundation

struct Location: Codable {
    let id: String
    var attributes: LocationAttributes
    var cnLabeledValue: CNLabeledValue<CNPostalAddress> {
        let address = CNMutablePostalAddress()
        address.street = [attributes.address1, attributes.address2].compactMap { $0 }.joined(separator: ", ")
        address.city = attributes.city ?? ""
        address.state = attributes.region ?? ""
        address.postalCode = attributes.postalCode ?? ""
        address.country = attributes.country ?? ""

        return CNLabeledValue(label: CNLabelWork, value: address)
    }
}
