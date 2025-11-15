//
//  BackupService.swift
//  MusicWall
//
//  Created by Chris Kelly on 11/15/25.
//

import Foundation

enum BackupService {
    /// Exports album IDs to a JSON file and returns the file URL
    static func exportAlbumIDs(_ ids: [String]) throws -> URL {
        guard !ids.isEmpty else {
            throw BackupServiceError.emptyExport
        }
        
        let jsonData = try JSONEncoder().encode(ids)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusicWall_AlbumIDs_\(Date().timeIntervalSince1970).json")
        
        try jsonData.write(to: tempURL)
        return tempURL
    }
    
    /// Imports album IDs from a file URL and returns the array of IDs
    static func importAlbumIDs(from url: URL) throws -> [String] {
        guard url.startAccessingSecurityScopedResource() else {
            throw BackupServiceError.fileAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let data = try Data(contentsOf: url)
        let ids = try JSONDecoder().decode([String].self, from: data)
        
        guard !ids.isEmpty else {
            throw BackupServiceError.emptyImport
        }
        
        return ids
    }
}

enum BackupServiceError: Error, LocalizedError {
    case emptyExport
    case emptyImport
    case fileAccessDenied
    case fileReadFailed(String)
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .emptyExport:
            return "No albums to export"
        case .emptyImport:
            return "Import file contains no album IDs"
        case .fileAccessDenied:
            return "Could not access file"
        case .fileReadFailed(let message):
            return "Failed to read file: \(message)"
        case .invalidFormat:
            return "Invalid file format"
        }
    }
}

