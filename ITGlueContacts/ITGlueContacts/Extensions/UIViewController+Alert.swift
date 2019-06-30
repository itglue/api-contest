//
//  UIViewController+Alert.swift
//  ITGlueContacts
//
//  Created by Michael Page on 26/6/19.
//

import UIKit

extension UIViewController {
    // Display a basic alert on the main thread.
    func alert(title: String?, message: String?) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let dismissAction = UIAlertAction(title: "Close", style: .default)
            alert.addAction(dismissAction)
            self.present(alert, animated: true)
        }
    }
}
