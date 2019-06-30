//
//  ITGlueAPI.swift
//  ITGlueContacts
//
//  Created by Michael Page on 14/6/19.
//

import Foundation

enum ITGlueAPIRequest: String {
    case contacts, locations
}

enum ITGlueAPIError: Error {
    case invalidData, networkIssue
}

class ITGlueAPI {
    let apiBaseURL = UserDefaults.standard.connectToEuropeanUnionEndpoint() ? "https://api.eu.itglue.com" : "https://api.itglue.com"
    var apiKey = String()

    init(apiKey: String = "") {
        do {
            self.apiKey = try KeychainItem().read()
        } catch {
            print("Error: Unable to read API key from Keychain.")
        }
    }

    // Contact IT Glue API for all contacts/locations, from all organizations.
    func getITGlueData(_ itGlueAPIRequest: ITGlueAPIRequest, completionHandler: @escaping (Result<(contacts: [Contact]?, locations: [Location]?), ITGlueAPIError>) -> Void) {
        // Ensure a valid URL is created.
        let apiRequestURL = apiBaseURL + "/\(itGlueAPIRequest.rawValue)?page[size]=1000"
        guard let url = URL(string: apiRequestURL) else {
            return
        }

        // Create the request, with the API key in the header.
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            // Ensure data is not nil and error is nil.
            guard let dataResponse = data, error == nil else {
                print(error?.localizedDescription ?? "Response Error")
                completionHandler(.failure(.networkIssue))
                return
            }

            do {
                let decoder = JSONDecoder()
                let resultTuple: ([Contact]?, [Location]?)
                switch itGlueAPIRequest {
                case .contacts:
                    // Decode JSON into a ContactData object.
                    let contactData = try decoder.decode(ContactData.self, from: dataResponse)
                    // Extract contacts from ContactData object.
                    let contacts = contactData.data
                    // Set the contacts portion of the result tuple.
                    resultTuple = (contacts: contacts, locations: nil)
                case .locations:
                    let locationData = try decoder.decode(LocationData.self, from: dataResponse)
                    let locations = locationData.data
                    resultTuple = (contacts: nil, locations: locations)
                }
                // Return the contacts/locations to the function caller.
                completionHandler(.success(resultTuple))
            } catch let parsingError {
                // Unable to decode dataResponse.
                print("Error", parsingError)
                completionHandler(.failure(.invalidData))
            }
        }
        // Execute task.
        task.resume()
    }
}
