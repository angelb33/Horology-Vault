//
//  DataBackupManager.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

enum DataPortabilityError: LocalizedError {
    case invalidCSVHeader
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidCSVHeader:
            "That file doesn't look like a Horology Vault watch export."
        case .decryptionFailed:
            "Couldn't unlock that backup — check the passphrase and try again."
        }
    }
}

struct CSVImportResult {
    let imported: Int
    let skipped: Int
}

struct RestoreSummary {
    let watchesRestored: Int
    let strapsRestored: Int
    let wishlistItemsRestored: Int
    let profileRestored: Bool
}

/// CSV export/import for the Vault (flat, human-editable) and an encrypted full-collection
/// backup/restore (nested, machine-only) — the two Data-section features from the
/// monetization plan's Phase 6. Both write/read through `ModelContext` directly rather than
/// going through the app's view-layer CRUD flows.
enum DataBackupManager {

    // MARK: CSV (Watches only — a flat format can't represent nested straps/service/wear/provenance)
    //
    // Deliberately excludes `Watch.purchasePrice`, unlike the encrypted backup below. CSV is meant
    // for portability (spreadsheets, sharing, printing) and travels as plaintext wherever it's
    // saved — a meaningfully different exposure than data that only ever leaves the device
    // encrypted. Not an oversight; don't add a price column here.

    static func exportWatchesCSV(context: ModelContext) throws -> String {
        let watches = try context.fetch(FetchDescriptor<Watch>(sortBy: [SortDescriptor(\.brand)]))
        let dateFormatter = ISO8601DateFormatter()
        var lines = [
            "Brand,Model,Reference Number,Complications,Case Diameter (mm),Lug-to-Lug (mm),Lug Width (mm),Acquisition Date"
        ]
        for watch in watches {
            let fields = [
                watch.brand,
                watch.model,
                watch.referenceNumber ?? "",
                watch.complications.joined(separator: ";"),
                watch.caseDiameterMM.formatted(),
                watch.lugToLugMM.formatted(),
                watch.lugWidthMM.formatted(),
                dateFormatter.string(from: watch.acquisitionDate)
            ]
            lines.append(fields.map { csvEscape($0) }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func importWatchesCSV(_ text: String, context: ModelContext) throws -> CSVImportResult {
        let rows = parseCSV(text)
        guard let header = rows.first, header.count >= 8,
              header[0].caseInsensitiveCompare("Brand") == .orderedSame
        else {
            throw DataPortabilityError.invalidCSVHeader
        }

        let dateFormatter = ISO8601DateFormatter()
        var imported = 0
        var skipped = 0

        for row in rows.dropFirst() {
            guard row.count >= 8 else { skipped += 1; continue }
            let brand = row[0].trimmingCharacters(in: .whitespaces)
            let model = row[1].trimmingCharacters(in: .whitespaces)
            guard !brand.isEmpty, !model.isEmpty,
                  let caseDiameter = Double(row[4]),
                  let lugToLug = Double(row[5]),
                  let lugWidth = Double(row[6])
            else {
                skipped += 1
                continue
            }
            let referenceNumber = row[2].trimmingCharacters(in: .whitespaces)
            let complications = row[3].split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let acquisitionDate = dateFormatter.date(from: row[7]) ?? Date()

            let watch = Watch(
                brand: brand,
                model: model,
                referenceNumber: referenceNumber.isEmpty ? nil : referenceNumber,
                complications: complications,
                caseDiameterMM: caseDiameter,
                lugToLugMM: lugToLug,
                lugWidthMM: lugWidth,
                acquisitionDate: acquisitionDate
            )
            context.insert(watch)
            imported += 1
        }

        return CSVImportResult(imported: imported, skipped: skipped)
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var insideQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let char = chars[i]
            if insideQuotes {
                if char == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else if char == "\"" {
                insideQuotes = true
            } else if char == "," {
                row.append(field)
                field = ""
            } else if char == "\n" {
                row.append(field)
                field = ""
                rows.append(row)
                row = []
            } else if char != "\r" {
                field.append(char)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    // MARK: Encrypted backup (full collection, passphrase-derived key)

    static func exportEncryptedBackup(context: ModelContext, passphrase: String) throws -> Data {
        let watches = try context.fetch(FetchDescriptor<Watch>())
        let allStraps = try context.fetch(FetchDescriptor<Strap>())
        let wishlistItems = try context.fetch(FetchDescriptor<WishlistItem>())
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first

        let watchBackups = watches.map { watch in
            WatchBackup(
                brand: watch.brand,
                model: watch.model,
                referenceNumber: watch.referenceNumber,
                complications: watch.complications,
                caseDiameterMM: watch.caseDiameterMM,
                lugToLugMM: watch.lugToLugMM,
                lugWidthMM: watch.lugWidthMM,
                acquisitionDate: watch.acquisitionDate,
                photoData: watch.photoData,
                purchasePrice: watch.purchasePrice,
                movementType: watch.movementType,
                powerReserveHours: watch.powerReserveHours,
                windReminderLeadTimeHours: watch.windReminderLeadTimeHours,
                serviceIntervalYears: watch.serviceIntervalYears,
                isServiceDueReminderEnabled: watch.isServiceDueReminderEnabled,
                isWindReminderEnabled: watch.isWindReminderEnabled,
                serialNumber: watch.serialNumber,
                caliber: watch.caliber,
                caseMaterial: watch.caseMaterial,
                dialColor: watch.dialColor,
                waterResistanceMeters: watch.waterResistanceMeters,
                boxAndPapersStatus: watch.boxAndPapersStatus,
                condition: watch.condition,
                warrantyExpirationDate: watch.warrantyExpirationDate,
                insuredValue: watch.insuredValue,
                appraisalDate: watch.appraisalDate,
                serviceRecords: watch.serviceRecords.map {
                    ServiceRecordBackup(datePerformed: $0.datePerformed, serviceType: $0.serviceType, accuracyDeltaSPD: $0.accuracyDeltaSPD)
                },
                wearLogs: watch.wearLogs.map {
                    WearLogBackup(dateWorn: $0.dateWorn, notes: $0.notes)
                },
                provenanceDocs: watch.provenanceDocs.map {
                    ProvenanceDocBackup(docType: $0.docType, fileName: $0.fileName, dateAdded: $0.dateAdded, fileData: $0.fileData)
                },
                windLogs: watch.windLogs.map {
                    WindLogBackup(dateWound: $0.dateWound)
                }
            )
        }

        let strapBackups = allStraps.map { strap -> StrapBackup in
            let attachedIndex = strap.attachedWatch.flatMap { attachedWatch in
                watches.firstIndex(where: { $0 === attachedWatch })
            }
            return StrapBackup(
                name: strap.name,
                material: strap.material,
                widthMM: strap.widthMM,
                lengthMM: strap.lengthMM,
                notes: strap.notes,
                attachedWatchIndex: attachedIndex
            )
        }

        let wishlistBackups = wishlistItems.map {
            WishlistItemBackup(brand: $0.brand, model: $0.model, targetPrice: $0.targetPrice, notes: $0.notes, priceAlertEnabled: $0.priceAlertEnabled)
        }

        let profileBackup = profile.map {
            UserProfileBackup(wristTopWidthCM: $0.wristTopWidthCM, wristSideDepthCM: $0.wristSideDepthCM)
        }

        let payload = BackupPayload(
            watches: watchBackups,
            straps: strapBackups,
            wishlistItems: wishlistBackups,
            userProfile: profileBackup
        )

        let jsonData = try JSONEncoder.horologyVault.encode(payload)
        return try encrypt(jsonData, passphrase: passphrase)
    }

    /// Restores additively (inserts alongside whatever's already in the store) rather than
    /// replacing the collection outright — a silent full wipe-and-replace is a much easier
    /// way to lose data than a merge is to create duplicates.
    static func importEncryptedBackup(_ data: Data, passphrase: String, context: ModelContext) throws -> RestoreSummary {
        let jsonData = try decrypt(data, passphrase: passphrase)
        let payload = try JSONDecoder.horologyVault.decode(BackupPayload.self, from: jsonData)

        var insertedWatches: [Watch] = []
        for watchBackup in payload.watches {
            let watch = Watch(
                brand: watchBackup.brand,
                model: watchBackup.model,
                referenceNumber: watchBackup.referenceNumber,
                complications: watchBackup.complications,
                caseDiameterMM: watchBackup.caseDiameterMM,
                lugToLugMM: watchBackup.lugToLugMM,
                lugWidthMM: watchBackup.lugWidthMM,
                acquisitionDate: watchBackup.acquisitionDate,
                photoData: watchBackup.photoData,
                purchasePrice: watchBackup.purchasePrice,
                movementType: watchBackup.movementType,
                powerReserveHours: watchBackup.powerReserveHours,
                windReminderLeadTimeHours: watchBackup.windReminderLeadTimeHours,
                serialNumber: watchBackup.serialNumber,
                caliber: watchBackup.caliber,
                caseMaterial: watchBackup.caseMaterial,
                dialColor: watchBackup.dialColor,
                waterResistanceMeters: watchBackup.waterResistanceMeters,
                boxAndPapersStatus: watchBackup.boxAndPapersStatus,
                condition: watchBackup.condition,
                warrantyExpirationDate: watchBackup.warrantyExpirationDate,
                insuredValue: watchBackup.insuredValue,
                appraisalDate: watchBackup.appraisalDate
            )
            watch.serviceIntervalYears = watchBackup.serviceIntervalYears
            watch.isServiceDueReminderEnabled = watchBackup.isServiceDueReminderEnabled
            watch.isWindReminderEnabled = watchBackup.isWindReminderEnabled
            context.insert(watch)
            for record in watchBackup.serviceRecords {
                context.insert(ServiceRecord(datePerformed: record.datePerformed, serviceType: record.serviceType, accuracyDeltaSPD: record.accuracyDeltaSPD, watch: watch))
            }
            for entry in watchBackup.wearLogs {
                context.insert(WearLog(dateWorn: entry.dateWorn, notes: entry.notes, watch: watch))
            }
            for doc in watchBackup.provenanceDocs {
                context.insert(ProvenanceDoc(docType: doc.docType, fileData: doc.fileData, fileName: doc.fileName, dateAdded: doc.dateAdded, watch: watch))
            }
            for wind in watchBackup.windLogs {
                context.insert(WindLog(dateWound: wind.dateWound, watch: watch))
            }
            insertedWatches.append(watch)
        }

        for strapBackup in payload.straps {
            let attachedWatch = strapBackup.attachedWatchIndex.flatMap { index in
                insertedWatches.indices.contains(index) ? insertedWatches[index] : nil
            }
            context.insert(Strap(
                name: strapBackup.name,
                material: strapBackup.material,
                widthMM: strapBackup.widthMM,
                lengthMM: strapBackup.lengthMM,
                notes: strapBackup.notes,
                attachedWatch: attachedWatch
            ))
        }

        for item in payload.wishlistItems {
            context.insert(WishlistItem(brand: item.brand, model: item.model, targetPrice: item.targetPrice, notes: item.notes, priceAlertEnabled: item.priceAlertEnabled))
        }

        if let profileBackup = payload.userProfile {
            let existingProfiles = try context.fetch(FetchDescriptor<UserProfile>())
            if let existing = existingProfiles.first {
                existing.wristTopWidthCM = profileBackup.wristTopWidthCM
                existing.wristSideDepthCM = profileBackup.wristSideDepthCM
            } else {
                context.insert(UserProfile(wristTopWidthCM: profileBackup.wristTopWidthCM, wristSideDepthCM: profileBackup.wristSideDepthCM))
            }
        }

        return RestoreSummary(
            watchesRestored: payload.watches.count,
            strapsRestored: payload.straps.count,
            wishlistItemsRestored: payload.wishlistItems.count,
            profileRestored: payload.userProfile != nil
        )
    }

    /// Derives the AES key straight from the passphrase via SHA256 — no PBKDF2/salt, since this
    /// only needs to keep a local file from being casually readable, not resist a targeted
    /// offline attack on a stolen backup.
    private static func deriveKey(from passphrase: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(passphrase.utf8)))
    }

    private static func encrypt(_ data: Data, passphrase: String) throws -> Data {
        let key = deriveKey(from: passphrase)
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw DataPortabilityError.decryptionFailed
        }
        return combined
    }

    private static func decrypt(_ data: Data, passphrase: String) throws -> Data {
        let key = deriveKey(from: passphrase)
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw DataPortabilityError.decryptionFailed
        }
    }
}

// MARK: - Backup DTOs (plain Codable snapshots, decoupled from the SwiftData models)

private struct WatchBackup: Codable {
    var brand: String
    var model: String
    var referenceNumber: String?
    var complications: [String]
    var caseDiameterMM: Double
    var lugToLugMM: Double
    var lugWidthMM: Double
    var acquisitionDate: Date
    var photoData: Data?
    var purchasePrice: Double?
    // Winding Log / reminder fields (added 2026-07-17, previously missing from this struct
    // entirely — a real gap, since a restore would silently drop this data even though the
    // encrypted backup is meant to capture the entire collection).
    var movementType: MovementType?
    var powerReserveHours: Double?
    var windReminderLeadTimeHours: Double?
    var serviceIntervalYears: Int?
    var isServiceDueReminderEnabled: Bool?
    var isWindReminderEnabled: Bool?
    // Collector/insurance detail fields (added 2026-07-17, same session as the fields above).
    var serialNumber: String?
    var caliber: String?
    var caseMaterial: String?
    var dialColor: String?
    var waterResistanceMeters: Int?
    var boxAndPapersStatus: BoxAndPapersStatus?
    var condition: WatchCondition?
    var warrantyExpirationDate: Date?
    var insuredValue: Double?
    var appraisalDate: Date?
    var serviceRecords: [ServiceRecordBackup]
    var wearLogs: [WearLogBackup]
    var provenanceDocs: [ProvenanceDocBackup]
    var windLogs: [WindLogBackup]
}

private struct StrapBackup: Codable {
    var name: String?
    var material: String
    var widthMM: Double
    var lengthMM: Double?
    var notes: String?
    /// Index into this same payload's `watches` array, since a fresh restore has no
    /// persistent IDs yet to link against.
    var attachedWatchIndex: Int?
}

private struct ServiceRecordBackup: Codable {
    var datePerformed: Date
    var serviceType: String
    var accuracyDeltaSPD: Double
}

private struct WearLogBackup: Codable {
    var dateWorn: Date
    var notes: String?
}

private struct WindLogBackup: Codable {
    var dateWound: Date
}

private struct ProvenanceDocBackup: Codable {
    var docType: ProvenanceDocType
    var fileName: String?
    var dateAdded: Date
    var fileData: Data
}

private struct WishlistItemBackup: Codable {
    var brand: String
    var model: String
    var targetPrice: Double
    var notes: String
    var priceAlertEnabled: Bool
}

private struct UserProfileBackup: Codable {
    var wristTopWidthCM: Double
    var wristSideDepthCM: Double
}

private struct BackupPayload: Codable {
    var version: Int = 1
    var watches: [WatchBackup]
    var straps: [StrapBackup]
    var wishlistItems: [WishlistItemBackup]
    var userProfile: UserProfileBackup?
}

private extension JSONEncoder {
    static var horologyVault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var horologyVault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - FileDocument wrappers for .fileExporter

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
