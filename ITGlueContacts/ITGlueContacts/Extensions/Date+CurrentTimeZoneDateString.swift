//
//  Date+CurrentTimeZoneDateString.swift
//  ITGlueContacts
//
//  Created by Michael Page on 25/6/19.
//

import Foundation

extension Date {
    // Output a date string, based on the user's current time zone. Example: "26 Jun 2019 at 3:19 pm"
    func currentTimeZoneDateString() -> String {
        let format = DateFormatter()
        format.timeZone = .current
        format.dateStyle = .medium
        format.timeStyle = .short
        return format.string(from: self)
    }
}
