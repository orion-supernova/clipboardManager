//
//  CopiedFromApplication.swift
//  clipboardManager
//
//  Created by muratcankoc on 23/07/2024.
//

import AppKit

struct CopiedFromApplication: Codable {
    // MARK: - Properties
    let applicationTitle: String?
    let applicationProcessIdentifier: pid_t?
    
    // MARK: - Lifecycle
    init(withApplication application: NSRunningApplication) {
        self.applicationTitle = application.localizedName
        self.applicationProcessIdentifier = application.processIdentifier
    }
    
    // MARK: - Public Methods
    func getApplication() -> NSRunningApplication? {
        guard let identifier = self.applicationProcessIdentifier else { return nil }
        let app = NSRunningApplication(processIdentifier: identifier)
        return app
    }
    
    // MARK: - Data Conversion Methods
    // Convert CopiedFromApplication to Data
    func toData() throws -> Data {
        do {
            return try JSONEncoder().encode(self)
        } catch let error {
            print("DEBUG: ----- ", error.localizedDescription)
            return Data()
        }
    }
    // Convert Data to CopiedFromApplication
    static func fromData(_ data: Data) throws -> CopiedFromApplication {
        return try JSONDecoder().decode(CopiedFromApplication.self, from: data)
    }
}
