//
//  WelcomeViewController.swift
//  ITGlueContacts
//
//  Created by Michael Page on 25/6/19.
//

import UIKit

class WelcomeViewController: UIViewController {
    @IBOutlet var itGlueAPIKeyTextField: UITextField!
    @IBOutlet var continueButton: UIButton!
    @IBAction func editingChangedITGlueAPIKeyTextField(_ textField: UITextField) {
        guard let apiKey = textField.text else {
            return
        }

        if savedITGlueAPIKey(apiKey: apiKey) {
            continueButton.isEnabled = true
            UserDefaults.standard.setDisplayedAppIntro(true)
        } else {
            continueButton.isEnabled = false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // To stop keyboard appearing, when attempting to paste in IT Glue API key.
        itGlueAPIKeyTextField.inputView = UIView()
    }

    func savedITGlueAPIKey(apiKey: String) -> Bool {
        do {
            // First write the API key to Keychain
            try KeychainItem().write(apiKey)
        } catch {
            alert(title: "Keychain Error", message: "Unknown error while attempting to store the IT Glue API key.")
            return false
        }
        return true
    }
}
