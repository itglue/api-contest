//
//  Email.swift
//  ITGlueContacts
//
//  Created by Michael Page on 15/5/19.
//

import Contacts
import Foundation

struct Email: Codable {
    let address: String?
    let label: Label
    var cnLabeledValue: CNLabeledValue<NSString>? {
        guard let address = address else {
            return nil
        }
        return CNLabeledValue(label: label.localizedString, value: address as NSString)
    }

    private enum CodingKeys: String, CodingKey {
        case address = "value"
        case label = "label-name"
    }

    init(address: String, label: String?) {
        self.address = address
        if let label = label {
            self.label = Label(rawValue: label) ?? Label.other
        } else {
            self.label = Label.other
        }
    }
}
