//
//  RegisterTableViewCells.swift
//  ITGlueContacts
//
//  Created by Michael Page on 17/6/19.
//

import UIKit

// Required for displaying custom table view cells.
enum TableViewCellIdentifier: String {
    case contactCell = "ContactCell"
}

func registerTableViewCells(tableView: UITableView, cellIdentifiers: [TableViewCellIdentifier]) {
    for cellIdentifier in cellIdentifiers {
        // Load the cell nib.
        let cellNib = UINib(nibName: cellIdentifier.rawValue, bundle: nil)
        // Register cell nib to make dequeueReusableCell(withIdentifier) use it with associated identifier.
        tableView.register(cellNib, forCellReuseIdentifier: cellIdentifier.rawValue)
    }
}
