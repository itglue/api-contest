//
//  UserDefaults.swift
//  ITGlueContacts
//
//  Created by Michael Page on 22/6/19.
//

import Foundation

// UserDefaults is used for storing app settings.
enum UserDefaultsKeys: String {
    case displayedAppIntro, connectToEuropeanUnionEndpoint
}

extension UserDefaults {
    func setDisplayedAppIntro(_ value: Bool) {
        set(value, forKey: UserDefaultsKeys.displayedAppIntro.rawValue)
    }

    // Has the user been shown the welcome screen yet?
    func displayedAppIntro() -> Bool {
        return bool(forKey: UserDefaultsKeys.displayedAppIntro.rawValue)
    }

    func setConnectToEuropeanUnionEndpoint(_ value: Bool) {
        set(value, forKey: UserDefaultsKeys.connectToEuropeanUnionEndpoint.rawValue)
    }

    // Should the app use the EU API endpoint?
    func connectToEuropeanUnionEndpoint() -> Bool {
        return bool(forKey: UserDefaultsKeys.connectToEuropeanUnionEndpoint.rawValue)
    }
}
