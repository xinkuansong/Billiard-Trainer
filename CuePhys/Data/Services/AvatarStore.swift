import Foundation
import UIKit

protocol AvatarBackend: Sendable {
    func uploadAvatar(_ jpegData: Data) async throws -> UserDTO
    func fetchAvatar(revision: Int) async throws -> Data
    func deleteAvatar() async throws -> UserDTO
}

extension BackendSyncService: AvatarBackend {}

@MainActor
final class AvatarStore: ObservableObject {
    enum Phase: Equatable { case idle, loading, uploading, deleting }

    static let shared = AvatarStore()
    @Published private(set) var image: UIImage?
    @Published private(set) var phase: Phase = .idle
    @Published var errorMessage: String?

    private let backend: any AvatarBackend
    private let directory: URL
    private var loadedKey: String?
    private var operationGeneration: UInt = 0

    init(backend: any AvatarBackend = BackendSyncService.shared,
         directory: URL? = nil) {
        self.backend = backend
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("ProfileAvatars", isDirectory: true)
    }

    func load(user: AppUser?, ownerKey: String) async {
        let key = cacheKey(user: user, ownerKey: ownerKey)
        guard loadedKey != key else { return }
        let operation = beginOperation()
        loadedKey = key
        phase = .idle
        errorMessage = nil
        image = nil

        if let data = try? Data(contentsOf: fileURL(for: key)), let cached = UIImage(data: data) {
            image = cached
            return
        }
        guard let user, user.provider != .anonymous, let revision = user.avatarRevision else { return }
        phase = .loading
        defer { finishOperation(operation) }
        do {
            let data = try await backend.fetchAvatar(revision: revision)
            guard operationGeneration == operation,
                  loadedKey == key,
                  let fetched = UIImage(data: data) else { return }
            image = fetched
            try? persist(data, key: key)
        } catch {
            guard operationGeneration == operation, loadedKey == key else { return }
            errorMessage = "头像加载失败，可稍后重试"
        }
    }

    func save(_ selected: UIImage, user: AppUser?, ownerKey: String,
              authState: AuthState) async -> Bool {
        guard let jpeg = AvatarImageProcessor.jpegData(selected) else {
            errorMessage = "无法处理这张图片，请换一张重试"
            return false
        }
        let previous = image
        let previousKey = cacheKey(user: user, ownerKey: ownerKey)
        let operation = beginOperation()
        loadedKey = previousKey
        phase = .idle
        image = UIImage(data: jpeg)
        errorMessage = nil

        guard let user, user.provider != .anonymous else {
            let key = cacheKey(user: user, ownerKey: ownerKey)
            loadedKey = key
            do {
                try persist(jpeg, key: key)
                return true
            } catch {
                image = previous
                errorMessage = "头像保存失败，请稍后重试"
                return false
            }
        }

        phase = .uploading
        defer { finishOperation(operation) }
        do {
            let dto = try await backend.uploadAvatar(jpeg)
            guard operationGeneration == operation else { return false }
            guard dto.id == user.id, OwnerKey.account(dto.id) == ownerKey else {
                restorePreview(previous, operationKey: previousKey)
                if isCurrentAccount(userId: user.id, ownerKey: ownerKey, authState: authState) {
                    errorMessage = "头像服务返回了不匹配的账号，本次修改未应用"
                }
                return false
            }
            guard isCurrentAccount(userId: user.id, ownerKey: ownerKey, authState: authState) else {
                discardPreview(operationKey: previousKey)
                return false
            }
            let updated = AppUser(dto: dto)
            authState.replaceAuthenticatedUser(updated)
            let key = cacheKey(user: updated, ownerKey: ownerKey)
            loadedKey = key
            try? persist(jpeg, key: key)
            if previousKey != key { try? FileManager.default.removeItem(at: fileURL(for: previousKey)) }
            image = UIImage(data: jpeg)
            return true
        } catch {
            guard operationGeneration == operation else { return false }
            if isCurrentAccount(userId: user.id, ownerKey: ownerKey, authState: authState) {
                restorePreview(previous, operationKey: previousKey)
                errorMessage = error.localizedDescription
            } else {
                discardPreview(operationKey: previousKey)
            }
            return false
        }
    }

    func delete(user: AppUser?, ownerKey: String, authState: AuthState) async -> Bool {
        let oldImage = image
        let oldKey = cacheKey(user: user, ownerKey: ownerKey)
        let operation = beginOperation()
        loadedKey = oldKey
        errorMessage = nil
        phase = .deleting
        defer { finishOperation(operation) }

        do {
            if let user, user.provider != .anonymous {
                let dto = try await backend.deleteAvatar()
                guard operationGeneration == operation else { return false }
                guard dto.id == user.id else { throw AvatarStoreError.accountChanged }
                guard isCurrentAccount(userId: user.id, ownerKey: ownerKey,
                                       authState: authState) else {
                    discardPreview(operationKey: oldKey)
                    return false
                }
                authState.replaceAuthenticatedUser(AppUser(dto: dto))
            }
            image = nil
            loadedKey = cacheKey(user: authState.currentUser, ownerKey: ownerKey)
            try? FileManager.default.removeItem(at: fileURL(for: oldKey))
            return true
        } catch {
            guard operationGeneration == operation else { return false }
            let stillCurrent = user.map {
                isCurrentAccount(userId: $0.id, ownerKey: ownerKey, authState: authState)
            } ?? authState.isAnonymous
            if stillCurrent {
                restorePreview(oldImage, operationKey: oldKey)
                errorMessage = error.localizedDescription
            } else {
                discardPreview(operationKey: oldKey)
            }
            return false
        }
    }

    var diskUsage: Int64 {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return urls.reduce(into: 0) { total, url in
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    /// Removes every revision cached for one deleted account. A user may have several files
    /// after successive avatar updates, so deleting only the current revision is insufficient.
    @discardableResult
    func removeCachedAccountData(userId: String) -> Bool {
        let prefix = "account-\(safe(userId))-r"
        if loadedKey?.hasPrefix(prefix) == true {
            cancelOperations()
            image = nil
            loadedKey = nil
        }
        return removeCachedFiles { $0.lastPathComponent.hasPrefix(prefix) }
    }

    /// Clears only derived avatar files. Server profile data and guest/account preferences are
    /// not cache and must remain untouched by Settings > Clear Cache.
    @discardableResult
    func clearDiskCache() -> Bool {
        cancelOperations()
        image = nil
        loadedKey = nil
        return removeCachedFiles { $0.pathExtension.lowercased() == "jpg" }
    }

    private func cacheKey(user: AppUser?, ownerKey: String) -> String {
        if let user, user.provider != .anonymous {
            return "account-\(safe(user.id))-r\(user.avatarRevision ?? 0)"
        }
        return "guest-\(safe(ownerKey))"
    }

    private func safe(_ value: String) -> String {
        value.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" }.reduce("", { $0 + String($1) })
    }

    private func isCurrentAccount(userId: String, ownerKey: String, authState: AuthState) -> Bool {
        authState.isLoggedIn
            && authState.currentUser?.id == userId
            && OwnerKey.account(userId) == ownerKey
    }

    private func restorePreview(_ previous: UIImage?, operationKey: String) {
        guard loadedKey == operationKey else { return }
        image = previous
    }

    private func discardPreview(operationKey: String) {
        guard loadedKey == operationKey else { return }
        image = nil
        loadedKey = nil
        errorMessage = nil
    }

    private func beginOperation() -> UInt {
        operationGeneration &+= 1
        return operationGeneration
    }

    private func finishOperation(_ operation: UInt) {
        guard operationGeneration == operation else { return }
        phase = .idle
    }

    private func cancelOperations() {
        operationGeneration &+= 1
        phase = .idle
    }

    private func fileURL(for key: String) -> URL { directory.appendingPathComponent("\(key).jpg") }

    private func persist(_ data: Data, key: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(for: key), options: .atomic)
    }

    private func removeCachedFiles(where shouldRemove: (URL) -> Bool) -> Bool {
        guard FileManager.default.fileExists(atPath: directory.path) else { return true }
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for url in urls where shouldRemove(url) {
                try FileManager.default.removeItem(at: url)
            }
            return true
        } catch {
            errorMessage = "本机头像缓存清理失败，请稍后重试"
            return false
        }
    }
}

enum AvatarStoreError: LocalizedError {
    case accountChanged
    var errorDescription: String? { "账号已切换，本次头像未应用" }
}

enum AvatarImageProcessor {
    static func cropped(_ image: UIImage, zoom: CGFloat = 1) -> UIImage {
        let normalized = normalized(image)
        let side = min(normalized.size.width, normalized.size.height) / max(1, zoom)
        let origin = CGPoint(x: (normalized.size.width - side) / 2,
                             y: (normalized.size.height - side) / 2)
        guard let cg = normalized.cgImage?.cropping(to: CGRect(origin: origin, size: CGSize(width: side, height: side))) else {
            return normalized
        }
        return UIImage(cgImage: cg, scale: normalized.scale, orientation: .up)
    }

    static func jpegData(_ image: UIImage) -> Data? {
        let cropped = cropped(image)
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in cropped.draw(in: CGRect(origin: .zero, size: size)) }
        var quality: CGFloat = 0.88
        var data = resized.jpegData(compressionQuality: quality)
        while let current = data, current.count > 1_000_000, quality > 0.35 {
            quality -= 0.1
            data = resized.jpegData(compressionQuality: quality)
        }
        return data
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }
}
