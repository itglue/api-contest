//
//  ContactsViewController.swift
//  ITGlueContacts
//
//  Created by Michael Page on 15/6/19.
//

import ContactsUI
import UIKit

class ContactsViewController: UIViewController {
    @IBOutlet var tableView: UITableView!
    @IBOutlet var settingsButton: UIBarButtonItem!

    // Overlaid search results table view.
    private var searchResultsViewController: SearchResultsViewController!

    // Search controller needed for filtering.
    private var searchController: UISearchController!

    // An array of filtered search results.
    private var searchResults = [Contact]()

    // An array of unique starting characters of each contact's name. Used to define table sections.
    private var tableSections = [String]()

    // A dictionary containing all contacts, keys are the same unique starting characters from tableSections.
    private var contactsDictionary = [String: [Contact]]()

    override func viewDidLoad() {
        super.viewDidLoad()

        prepareSearchController()

        prepareNavigationController()

        registerTableViewCells(tableView: tableView, cellIdentifiers: [.contactCell])

        // Add observer that is triggered when new data has loaded.
        NotificationCenter.default.addObserver(self, selector: #selector(allContactDataUpdated(_:)), name: Constants.Notifications.allContactDataUpdated.name, object: nil)

        // Fetch contacts.
        fetchContactData()
    }

    // Triggered when new data has loaded.
    @objc private func allContactDataUpdated(_ notification: Notification) {
        tableSections = DataSource.shared.allContactsSections
        contactsDictionary = DataSource.shared.allContactsDictionary

        // Reload the table view on the main thread.
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    private func fetchContactData() {
        // Get the latest contact data.
        DataSource.shared.updateData { result in
            var title = String()
            var message = String()

            switch result {
            case .success:
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
                self.alert(title: title, message: message)
            }
        }
    }

    private func prepareNavigationController() {
        // Allows the navigation bar title ("IT Glue Contacts") to be displayed in large text at the top of the table view.
        navigationController?.navigationBar.prefersLargeTitles = true
        // Set back button to "Contacts".
        let backBarButtonItem = UIBarButtonItem()
        backBarButtonItem.title = "Contacts"
        navigationItem.backBarButtonItem = backBarButtonItem
    }

    private func prepareSearchController() {
        // Initialize SearchResultsViewController.
        searchResultsViewController = SearchResultsViewController()
        // Make ContactsViewController (self) the delegate of searchResultsViewController's table view.
        // This causes searchResultsViewController's table view to run ContactsViewController's didSelectRowAt method.
        searchResultsViewController.tableView.delegate = self

        // Initialize UISearchController and set searchResultsViewController as the results view controller.
        searchController = UISearchController(searchResultsController: searchResultsViewController)
        // Make ContactsViewController (self) the delegate of searchController's searchResultsUpdater.
        // As ContactsViewController is a subclass of UISearchResultsUpdating, it is notified when the updateSearchResults is called.
        searchController.searchResultsUpdater = self
        // Stop auto capitalization of search bar input.
        searchController.searchBar.autocapitalizationType = .none

        // Add search to the navigation controller.
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        // Required to present searchResultsViewController correctly on top of ContactsViewController.
        definesPresentationContext = true
    }
}

extension ContactsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        // Clear out any previous search results.
        searchResults.removeAll()

        // Ensure search bar text is set.
        guard var searchBarText = searchController.searchBar.text else {
            return
        }

        // Remove any leading and trailing whitespace.
        searchBarText = searchBarText.trimmingCharacters(in: .whitespacesAndNewlines)

        // After removing leading and trailing whitespace, ensure search bar text is not empty.
        if !searchBarText.isEmpty {
            // Filter through all contacts to generate search results.
            searchResults = DataSource.shared.allContacts.filter({ (contact) -> Bool in
                let contactName = contact.attributes.fullName
                let contactOrganizationName = contact.attributes.organizationName

                // Split search text into an array of items (probably words).
                let searchItems = searchBarText.components(separatedBy: " ")

                var matchFound = false

                // Loop through each search item.
                for searchItem in searchItems {
                    // Sets matchFound to true if the search item is found in the contact's name or organization name.
                    matchFound = contactName.range(of: searchItem, options: [.caseInsensitive]) != nil || contactOrganizationName.range(of: searchItem, options: [.caseInsensitive]) != nil
                    // As soon as a match is found end the loop.
                    if matchFound {
                        break
                    }
                }

                return matchFound
            })
        }

        if let resultsController = searchController.searchResultsController as? SearchResultsViewController {
            // Update the results controller with the search results.
            resultsController.searchResults = searchResults
            resultsController.tableView.reloadData()
        }
    }
}

extension ContactsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        // Creates a table section for each unique starting character.
        return tableSections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Create a new cell.
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCellIdentifier.contactCell.rawValue, for: indexPath) as! ContactCell
        // Get the current section character.
        let sectionCharacter = tableSections[indexPath.section]
        // Get contacts under that section character.
        let sectionContacts = contactsDictionary[sectionCharacter] ?? []
        // Set the contact for the current section row.
        let contact = sectionContacts[indexPath.row]
        cell.configure(for: contact)
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // The current section character.
        let sectionCharacter = tableSections[section]
        // Contacts under section character.
        let sectionContacts = contactsDictionary[sectionCharacter] ?? []
        // Return the number of contacts under that section character.
        return sectionContacts.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // Creates a header for each section (character).
        return tableSections[section]
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        // Display an index list on the right of the table view.
        return tableSections
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedContact: Contact?

        if tableView == self.tableView {
            // The current section character.
            let sectionCharacter = tableSections[indexPath.section]
            // Contacts under section character.
            let sectionContacts = contactsDictionary[sectionCharacter] ?? []
            // Selected contact.
            selectedContact = sectionContacts[indexPath.row]
        } else {
            selectedContact = searchResults[indexPath.row]
        }

        if let selectedContact = selectedContact {
            // Create a standard CNContactViewController to display the contact data.
            let contactViewContoller = CNContactViewController(forUnknownContact: selectedContact.cnContactValue)
            navigationController?.pushViewController(contactViewContoller, animated: true)
        }

        // Deselect row on tap.
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
