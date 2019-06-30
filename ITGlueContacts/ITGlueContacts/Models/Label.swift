//
//  Label.swift
//  ITGlueContacts
//
//  Created by Michael Page on 15/5/19.
//

import Contacts
import Foundation

enum Label: String, Codable {
    case work = "Work"
    case home = "Home"
    case mobile = "Mobile"
    case fax = "Fax"
    case main = "Main"
    case other = "Other"
    var localizedString: String {
        switch self {
        case .work:
            return CNLabelWork
        case .home:
            return CNLabelHome
        case .mobile:
            return CNLabelPhoneNumberMobile
        case .fax:
            return CNLabelPhoneNumberWorkFax
        case .main:
            return CNLabelPhoneNumberMain
        case .other:
            return CNLabelOther
        }
    }
}
