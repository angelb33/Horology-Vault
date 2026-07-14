//
//  ProvenanceDoc.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/13/26.
//

import Foundation
import SwiftData

enum ProvenanceDocType: String, Codable, CaseIterable, Identifiable {
    case receipt = "Receipt"
    case warranty = "Warranty"
    case appraisal = "Appraisal"

    var id: String { rawValue }
}

@Model
final class ProvenanceDoc {
    var docType: ProvenanceDocType
    var fileName: String?
    var dateAdded: Date

    @Attribute(.externalStorage)
    var fileData: Data

    var watch: Watch?

    init(
        docType: ProvenanceDocType,
        fileData: Data,
        fileName: String? = nil,
        dateAdded: Date = Date(),
        watch: Watch? = nil
    ) {
        self.docType = docType
        self.fileData = fileData
        self.fileName = fileName
        self.dateAdded = dateAdded
        self.watch = watch
    }
}
