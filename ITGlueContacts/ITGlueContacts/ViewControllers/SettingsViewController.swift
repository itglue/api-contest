//
//  SettingsViewController.swift
//  ITGlueContacts
//
//  Created by Michael Page on 19/6/19.
//

import UIKit

class SettingsViewController: UITableViewController {
    @IBAction func didTapUpdateContactsNowButton(_ sender: Any) {
        fetchContactData()
    }

    @IBAction func didTapUpdateITGlueAPIKeyButton(_ sender: Any) {
        presentSetITGlueAPIKeyAlert()
    }

    @IBAction func didTapImportITGlueContactsIntoAppleContactsButton(_ sender: Any) {
        presentImportITGlueContactsAlert()
    }

    @IBOutlet var connectToEuropeanUnionEndpointSwitch: UISwitch!
    @IBAction func didToggleConnectToEuropeanUnionEndpointSwitch(_ sender: UISwitch) {
        UserDefaults.standard.setConnectToEuropeanUnionEndpoint(sender.isOn)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Update the connectToEuropeanUnionEndpointSwitch to the current setting.
        connectToEuropeanUnionEndpointSwitch.isOn = UserDefaults.standard.connectToEuropeanUnionEndpoint()
    }

    private func setITGlueAPIKey(_ apiKey: String) {
        do {
            try KeychainItem().write(apiKey)
        } catch {
            let title = "Keychain Error"
            let message = "Unknown error while attempting to store the IT Glue API key."
            alert(title: title, message: message)
        }
    }

    private func presentSetITGlueAPIKeyAlert() {
        let alert = UIAlertController(title: "IT Glue API Key", message: "Please paste in your IT Glue API key:", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "IT Glue API key"
        }
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            if let userInput = alert.textFields?.first?.text {
                self.setITGlueAPIKey(userInput)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }

    private func presentImportITGlueContactsAlert() {
        if #available(iOS 13, *) {
            self.alert(title: "Unsupported iOS Version", message: "A bug in iOS 13 prevents this feature from functioning correctly. The issue has been reported to Apple.")
            return
        }

        let alert = UIAlertController(title: "Import IT Glue Contacts", message: "Apple contacts with matching names will have their job title, organization name, work postal address and notes replaced with the respective IT Glue data. Existing phone numbers and email addresses are not removed. Would you like to proceed?", preferredStyle: .alert)
        let importAction = UIAlertAction(title: "Import", style: .destructive) { _ in
            do {
                try AppleContacts().importAllITGlueContacts { result in
                    switch result {
                    case .success:
                        print("Success: Completed importing all locally cached IT Glue Contacts into Apple Contacts.")
                        self.alert(title: "Import Complete", message: nil)
                    case let .failure(appleContactsError):
                        let title = "Failed to Import Contacts"
                        switch appleContactsError {
                        case .missingRequiredGroup, .missingRequiredContainer, .unableToAddGroup:
                            self.alert(title: title, message: "Please create an \"IT Glue\" contacts group, with the Contacts Mac app and try again.")
                        case .unsupportedContactsContainer:
                            self.alert(title: title, message: "Please ensure an iCloud, CardDAV or Exchange account is set under: Settings > Contacts > Default Account.")
                        case .unableToIdentifyContainer:
                            self.alert(title: title, message: "Multiple \"IT Glue\" contact groups found. There should only be one, please remove duplicate groups.")
                        case .unableToSearchContacts:
                            self.alert(title: title, message: "Unable to access contacts, please enable contact access in Settings > IT Glue Contacts")
                        default:
                            self.alert(title: title, message: "Error: \(appleContactsError)")
                        }
                    }
                }
            } catch {
                self.alert(title: "Error", message: "Unable to import contacts!")
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(importAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }

    private func fetchContactData() {
        // Get the latest contact data.
        DataSource.shared.updateData { result in
            var title = String()
            var message = String()

            switch result {
            case .success:
                title = "Contact Update Complete"
                // Trigger a reload of the main table view.
                NotificationCenter.default.post(Constants.Notifications.allContactDataUpdated)
            case let .failure(error):
                print(error.localizedDescription)
                title = "Error Updating Contacts"
                switch error {
                case .invalidData:
                    message = "Failed to obtain valid data from IT Glue. Please check IT Glue API key."
                case .networkIssue:
                    message = "Unable to communicate with IT Glue, please check your network connection."
                }
            }

            self.alert(title: title, message: message)
            DispatchQueue.main.async {
                // Reload the table to update the footer last sync timestamp.
                self.tableView.reloadData()
            }
        }
    }
}

extension SettingsViewController {
    // Override will display footer view to update footer of first cell with last sync timestamp.
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if section == 0 {
            let footer = view as! UITableViewHeaderFooterView
            let footerText = "Last sync: \(DataSource.shared.lastUpdateTimestamp?.currentTimeZoneDateString() ?? "Never")"
            footer.textLabel?.text = footerText
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect row on tap.
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
