//
//  String+FullRange.swift
//  ITGlueContacts
//
//  Created by Michael Page on 16/6/19.
//

import Foundation

extension String {
    // Returns NSRange of a string.
    func fullRange() -> NSRange {
        return NSMakeRange(0, count)
    }
}
