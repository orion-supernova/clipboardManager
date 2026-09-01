//
//  ClipboardStoreClient.swift
//  clipboardManager
//

import ComposableArchitecture
import Foundation

struct ClipboardStoreClient: Sendable {
    var prepare: @Sendable () async throws -> Void
    var load: @Sendable (ItemQuery) async throws -> [ClipboardItem]
    var ingest: @Sendable (PasteboardSnapshot, IngestOptions) async throws -> IngestResult
    var payload: @Sendable (UUID) async throws -> ClipboardPayload?
    var generateFileThumbnail: @Sendable (UUID) async throws -> ClipboardItem?
    var setLinkMetadata: @Sendable (LinkMetadata, UUID) async throws -> ClipboardItem?
    var setRecognizedText: @Sendable (String, UUID) async throws -> ClipboardItem?
    var touch: @Sendable (UUID) async throws -> Void
    var setPinned: @Sendable (UUID, Bool) async throws -> Void
    var delete: @Sendable ([UUID]) async throws -> Void
    var deleteAll: @Sendable () async throws -> Void
    var prune: @Sendable (RetentionPolicy) async throws -> [UUID]
    var folders: @Sendable () async throws -> [ClipboardFolder]
    var createFolder: @Sendable (String) async throws -> ClipboardFolder
    var renameFolder: @Sendable (UUID, String) async throws -> Void
    var deleteFolder: @Sendable (UUID, FolderDeletion) async throws -> Void
    var moveItem: @Sendable (UUID, UUID?) async throws -> Void
    var storageFootprint: @Sendable () async -> Int64
    var imageURL: @Sendable (String) -> URL
    var thumbnailURL: @Sendable (String) -> URL

    static func live(store: ClipboardStore) -> ClipboardStoreClient {
        ClipboardStoreClient(
            prepare: { try await store.prepare() },
            load: { try await store.load($0) },
            ingest: { try await store.ingest($0, options: $1) },
            payload: { try await store.payload(for: $0) },
            generateFileThumbnail: { try await store.generateFileThumbnail(for: $0) },
            setLinkMetadata: { try await store.setLinkMetadata($0, for: $1) },
            setRecognizedText: { try await store.setRecognizedText($0, for: $1) },
            touch: { _ = try await store.touch(id: $0) },
            setPinned: { try await store.setPinned(id: $0, $1) },
            delete: { try await store.delete(ids: $0) },
            deleteAll: { try await store.deleteAll() },
            prune: { try await store.prune($0) },
            folders: { try await store.folders() },
            createFolder: { try await store.createFolder(named: $0) },
            renameFolder: { try await store.renameFolder(id: $0, to: $1) },
            deleteFolder: { try await store.deleteFolder(id: $0, strategy: $1) },
            moveItem: { try await store.moveItem(id: $0, toFolder: $1) },
            storageFootprint: { await store.storageFootprint() },
            imageURL: { store.blobs.imageURL(for: $0) },
            thumbnailURL: { store.blobs.thumbnailURL(for: $0) }
        )
    }
}

extension ClipboardStoreClient: DependencyKey {
    static let liveValue = ClipboardStoreClient.live(
        store: ClipboardStore(persistence: PersistenceController(), blobs: BlobStore())
    )

    static let previewValue = ClipboardStoreClient.live(
        store: ClipboardStore(
            persistence: PersistenceController(inMemory: true),
            blobs: BlobStore(root: FileManager.default.temporaryDirectory.appending(path: "ClipboardPreview"))
        )
    )
}

extension DependencyValues {
    var clipboardStore: ClipboardStoreClient {
        get { self[ClipboardStoreClient.self] }
        set { self[ClipboardStoreClient.self] = newValue }
    }
}
