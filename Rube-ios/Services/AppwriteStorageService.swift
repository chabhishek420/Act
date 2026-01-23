//
//  AppwriteStorageService.swift
//  Rube-ios
//
//  Service for managing file uploads and downloads via Appwrite Storage
//

import Foundation
import Appwrite
import UIKit

@Observable
final class AppwriteStorageService {
    
    private let storage: Storage
    private let bucketId = "chat_attachments" // Ensure this bucket exists in Appwrite Console
    
    init() {
        self.storage = Storage(client)
    }
    
    // MARK: - Upload
    
    /// Uploads an image to Appwrite Storage
    func uploadImage(_ image: UIImage, name: String? = nil) async throws -> Attachment {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "StorageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        return try await uploadFile(
            data: data,
            name: name ?? "image_\(Int(Date().timeIntervalSince1970)).jpg",
            mimeType: "image/jpeg"
        )
    }
    
    /// General file upload
    func uploadFile(data: Data, name: String, mimeType: String) async throws -> Attachment {
        let fileId = ID.unique()
        
        let file = try await storage.createFile(
            bucketId: bucketId,
            fileId: fileId,
            file: InputFile.fromData(data, filename: name, mimeType: mimeType)
        )
        
        return Attachment(
            id: UUID().uuidString,
            fileId: file.id,
            bucketId: bucketId,
            name: name,
            mimeType: mimeType,
            size: data.count
        )
    }
    
    // MARK: - Download & View
    
    /// Gets a preview URL for an image (authenticated via project ID)
    func getPreviewURL(fileId: String, width: Int = 400) -> URL? {
        let endpoint = "https://nyc.cloud.appwrite.io/v1"
        let projectId = "6961fcac000432c6a72a"
        
        let urlString = "\(endpoint)/storage/buckets/\(bucketId)/files/\(fileId)/preview?project=\(projectId)&width=\(width)"
        return URL(string: urlString)
    }
    
    /// Gets a download/view URL
    func getViewURL(fileId: String) -> URL? {
        let endpoint = "https://nyc.cloud.appwrite.io/v1"
        let projectId = "6961fcac000432c6a72a"
        
        let urlString = "\(endpoint)/storage/buckets/\(bucketId)/files/\(fileId)/view?project=\(projectId)"
        return URL(string: urlString)
    }
    
    // MARK: - Delete
    
    func deleteFile(fileId: String) async throws {
        _ = try await storage.deleteFile(bucketId: bucketId, fileId: fileId)
    }
}
