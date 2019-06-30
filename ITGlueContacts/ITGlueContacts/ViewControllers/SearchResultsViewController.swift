//
//  SearchResultsViewController.swift
//  ITGlueContacts
//
//  Created by Michael Page on 17/6/19.
//

import ContactsUI
import UIKit

class SearchResultsViewController: UITableViewController {
    var searchResults = [Contact]()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Register contact cell.
        registerTableViewCells(tableView: tableView, cellIdentifiers: [.contactCell])
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCellIdentifier.contactCell.rawValue, for: indexPath) as! ContactCell
        let contact = searchResults[indexPath.row]
        cell.configure(for: contact)
        return cell
    }
}
