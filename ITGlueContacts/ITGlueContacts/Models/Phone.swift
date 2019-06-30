//
//  Phone.swift
//  ITGlueContacts
//
//  Created by Michael Page on 15/5/19.
//

import Contacts
import Foundation

struct Phone: Codable {
    let number: String?
    let extensionNumber: String?
    var numberAndExtensionNumber: String? {
        guard let number = number else {
            return nil
        }
        if let extensionNumber = extensionNumber {
            return "\(number),\(extensionNumber)"
        } else {
            return number
        }
    }

    let label: Label
    var cnLabeledValue: CNLabeledValue<CNPhoneNumber>? {
        guard let numberAndExtensionNumber = numberAndExtensionNumber else {
            return nil
        }
        return CNLabeledValue(label: label.localizedString, value: CNPhoneNumber(stringValue: numberAndExtensionNumber))
    }

    private enum CodingKeys: String, CodingKey {
        case number = "value"
        case extensionNumber = "extension"
        case label = "label-name"
    }

    init(number: String, extensionNumber: String?, label: String?) {
        self.number = number
        self.extensionNumber = extensionNumber
        if let label = label {
            self.label = Label(rawValue: label) ?? Label.other
        } else {
            self.label = Label.other
        }
    }
}
