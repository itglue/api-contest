//
//  ContactCell.swift
//  ITGlueContacts
//
//  Created by Michael Page on 15/6/19.
//

import UIKit

class ContactCell: UITableViewCell {
    @IBOutlet var contactTitleLabel: UILabel!
    @IBOutlet var contactSubtitleLabel: UILabel!

    func configure(for contact: Contact) {
        var contactTitle = String()
        var contactSubtitle = String()
        // Range of text to make bold (just last name or entire organization name).
        var boldStringRange = NSRange()

        if contact.isAnOrganizationLocation {
            // Set contact title to organization and location name.
            contactTitle = contact.attributes.location?.attributes.organizationNameAndLocationName ?? contact.attributes.organizationName
            // Bold organization name.
            boldStringRange = contact.attributes.organizationName.fullRange()
        } else {
            // Set contact title to full name.
            contactTitle = contact.attributes.fullName
            // Get length of last name.
            let lastNameLength = contact.attributes.lastName?.count ?? 0
            // Get length of full name.
            let fullNameLength = contact.attributes.fullName.count
            // Only bold the last name.
            boldStringRange = NSMakeRange((fullNameLength - lastNameLength), lastNameLength)
            // Set contact subtitle to organization and location name.
            contactSubtitle = contact.attributes.location?.attributes.organizationNameAndLocationName ?? contact.attributes.organizationName
        }

        let attributedString = NSMutableAttributedString(string: contactTitle)
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 17)]
        attributedString.setAttributes(attributes, range: boldStringRange)

        // "Contact Name" or "Organization Name - Location Name"
        contactTitleLabel.attributedText = attributedString
        // "Organization Name - Location Name" or do not display
        contactSubtitleLabel.text = contactSubtitle
    }
}
