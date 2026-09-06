import XCTest
import UIKit
import StoreKit
import StoreKitTest
import Combine
@testable import QiuJi

@MainActor
final class V53ProfilePreferencesTests: XCTestCase {
    func testLoggedInDisplayNameCommitsOnlyServerResponse() async {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.login(user: AppUser(id: "user-a", provider: .apple, displayName: "旧昵称"))
        let backend = ProfileUpdateBackend(result: .success(userDTO(name: "服务端昵称")))
        let store = OwnerProfileStore(ownerKey: OwnerKey.account("user-a"),
                                      defaults: defaults, backend: backend)
        store.load(from: auth.currentUser)

        let saved = await store.saveDisplayName("本地输入", authState: auth)
        XCTAssertTrue(saved)
        XCTAssertEqual(store.displayName, "服务端昵称")
        XCTAssertEqual(auth.currentUser?.displayName, "服务端昵称")
    }

    func testFailedDisplayNameDoesNotShowFalseSuccess() async {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.login(user: AppUser(id: "user-a", provider: .apple, displayName: "旧昵称"))
        let store = OwnerProfileStore(ownerKey: OwnerKey.account("user-a"), defaults: defaults,
                                      backend: ProfileUpdateBackend(result: .failure(TestFailure())))
        store.load(from: auth.currentUser)

        let saved = await store.saveDisplayName("假成功", authState: auth)
        XCTAssertFalse(saved)
        XCTAssertEqual(store.displayName, "旧昵称")
        XCTAssertEqual(auth.currentUser?.displayName, "旧昵称")
    }

    func testDisplayNameValidationMatchesServerTwentyCharacterLimit() async {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.loginAnonymously()
        let store = OwnerProfileStore(ownerKey: owner.guestOwnerKey, defaults: defaults)

        let accepted = await store.saveDisplayName(
            String(repeating: "球", count: 20), authState: auth
        )
        let rejected = await store.saveDisplayName(
            String(repeating: "球", count: 21), authState: auth
        )
        XCTAssertTrue(accepted)
        XCTAssertFalse(rejected)
        XCTAssertEqual(store.displayName, String(repeating: "球", count: 20))
        XCTAssertEqual(store.errorMessage, "昵称需为 1–20 个字符")
    }

    func testGuestProfilesAreSeparatedByOwner() async {
        let defaults = isolatedDefaults()
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: CurrentOwnerContext(defaults: defaults))
        auth.loginAnonymously()
        let first = OwnerProfileStore(ownerKey: "guest:first", defaults: defaults)
        _ = await first.saveDisplayName("一号游客", authState: auth)
        let second = OwnerProfileStore(ownerKey: "guest:second", defaults: defaults)
        XCTAssertEqual(first.displayName, "一号游客")
        XCTAssertEqual(second.displayName, "球迹用户")
    }

    func testLegacyGlobalProfileMigratesOnlyToDeviceGuest() {
        let defaults = isolatedDefaults()
        defaults.set("nineBall", forKey: "preferredSport")
        defaults.set("advanced", forKey: "skillLevel")
        defaults.set("fivePlus", forKey: "yearsPlaying")
        defaults.set(6, forKey: "weeklyGoalDays")
        let guestOwner = DeviceGuestIdentity.ownerKey(in: defaults)

        let guest = OwnerProfileStore(ownerKey: guestOwner, defaults: defaults)
        let account = OwnerProfileStore(ownerKey: OwnerKey.account("user-a"), defaults: defaults)

        XCTAssertEqual(guest.preferredSport, .nineBall)
        XCTAssertEqual(guest.skillLevel, .advanced)
        XCTAssertEqual(guest.yearsPlaying, .fivePlus)
        XCTAssertEqual(guest.weeklyGoalDays, 6)
        XCTAssertEqual(account.preferredSport, .chinese8)
        XCTAssertEqual(account.weeklyGoalDays, 3)
        XCTAssertNil(defaults.object(forKey: "preferredSport"))
        XCTAssertNil(defaults.object(forKey: "weeklyGoalDays"))
    }

    func testCanonicalServerYearsPlayingRestoresWithoutFallback() {
        let defaults = isolatedDefaults()
        let store = OwnerProfileStore(ownerKey: OwnerKey.account("user-a"), defaults: defaults)

        store.load(from: AppUser(
            id: "user-a",
            provider: .apple,
            yearsPlaying: YearsPlaying.threeToFive.rawValue
        ))

        XCTAssertEqual(store.yearsPlaying, .threeToFive)
    }

    func testAvatarUploadUpdatesRevisionAndFailureRollsBackPreview() async {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.login(user: AppUser(id: "user-a", provider: .apple, avatarRevision: nil))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let backend = AvatarTestBackend(uploadResult: .success(userDTO(name: nil, revision: 2)))
        let store = AvatarStore(backend: backend, directory: dir)
        let image = solidImage(.red)
        let uploaded = await store.save(image, user: auth.currentUser,
                                        ownerKey: OwnerKey.account("user-a"), authState: auth)
        XCTAssertTrue(uploaded)
        XCTAssertEqual(auth.currentUser?.avatarRevision, 2)
        XCTAssertNotNil(store.image)

        backend.uploadResult = .failure(TestFailure())
        let previous = store.image?.pngData()
        let failed = await store.save(solidImage(.blue), user: auth.currentUser,
                                      ownerKey: OwnerKey.account("user-a"), authState: auth)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.image?.pngData(), previous)
    }

    func testStaleAccountResponseCannotReplaceCurrentAuthenticatedUser() {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.login(user: AppUser(id: "user-b", provider: .apple, displayName: "账号 B"))

        auth.replaceAuthenticatedUser(
            AppUser(id: "user-a", provider: .apple, displayName: "迟到的账号 A")
        )

        XCTAssertEqual(auth.currentUser?.id, "user-b")
        XCTAssertEqual(auth.currentUser?.displayName, "账号 B")
    }

    func testDeletedAccountProfileCacheIsRemovedWithoutTouchingGuest() async {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.loginAnonymously()
        let guest = OwnerProfileStore(ownerKey: owner.guestOwnerKey, defaults: defaults)
        _ = await guest.saveDisplayName("保留的游客", authState: auth)

        let accountKey = OwnerKey.account("user-a")
        let account = OwnerProfileStore(ownerKey: accountKey, defaults: defaults)
        account.load(from: AppUser(id: "user-a", provider: .apple,
                                   displayName: "应删除的账号昵称",
                                   preferredSport: PreferredSport.nineBall.rawValue,
                                   skillLevel: SkillLevel.advanced.rawValue,
                                   yearsPlaying: YearsPlaying.fivePlus.rawValue,
                                   weeklyGoalDays: 6))

        OwnerProfileStore.removeLocalProfile(ownerKey: accountKey, in: defaults)

        let restoredAccount = OwnerProfileStore(ownerKey: accountKey, defaults: defaults)
        let restoredGuest = OwnerProfileStore(ownerKey: owner.guestOwnerKey, defaults: defaults)
        XCTAssertEqual(restoredAccount.displayName, "球迹用户")
        XCTAssertEqual(restoredAccount.preferredSport, .chinese8)
        XCTAssertEqual(restoredAccount.weeklyGoalDays, 3)
        XCTAssertEqual(restoredGuest.displayName, "保留的游客")
    }

    func testDeletedAccountAvatarCacheRemovesAllRevisionsAndKeepsOtherOwners() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("V53AvatarCleanup-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jpeg = try XCTUnwrap(solidImage(.red).jpegData(compressionQuality: 0.8))
        try jpeg.write(to: directory.appendingPathComponent("account-user-a-r1.jpg"))
        try jpeg.write(to: directory.appendingPathComponent("account-user-a-r2.jpg"))
        try jpeg.write(to: directory.appendingPathComponent("account-user-b-r1.jpg"))
        try jpeg.write(to: directory.appendingPathComponent("guest-device-r1.jpg"))
        let store = AvatarStore(backend: AvatarTestBackend(uploadResult: .failure(TestFailure())),
                                directory: directory)

        await store.load(user: AppUser(id: "user-a", provider: .apple, avatarRevision: 1),
                         ownerKey: OwnerKey.account("user-a"))
        XCTAssertNotNil(store.image)
        XCTAssertGreaterThan(store.diskUsage, 0)

        XCTAssertTrue(store.removeCachedAccountData(userId: "user-a"))
        XCTAssertNil(store.image)
        let names = try Set(FileManager.default.contentsOfDirectory(atPath: directory.path))
        XCTAssertFalse(names.contains("account-user-a-r1.jpg"))
        XCTAssertFalse(names.contains("account-user-a-r2.jpg"))
        XCTAssertTrue(names.contains("account-user-b-r1.jpg"))
        XCTAssertTrue(names.contains("guest-device-r1.jpg"))
    }

    func testLateAvatarUploadFromADoesNotOverwriteLoadedAvatarForB() async throws {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("V53AvatarRace-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let accountAKey = OwnerKey.account("user-a")
        let accountBKey = OwnerKey.account("user-b")
        let red = try XCTUnwrap(solidImage(.red).jpegData(compressionQuality: 0.8))
        let blue = try XCTUnwrap(solidImage(.blue).jpegData(compressionQuality: 0.8))
        try red.write(to: directory.appendingPathComponent("account-user-a-r1.jpg"))
        let backend = DelayedAvatarUploadBackend()
        let store = AvatarStore(backend: backend, directory: directory)
        auth.login(user: AppUser(id: "user-a", provider: .apple, avatarRevision: 1))
        await store.load(user: auth.currentUser, ownerKey: accountAKey)

        let upload = Task {
            await store.save(solidImage(.green), user: auth.currentUser,
                             ownerKey: accountAKey, authState: auth)
        }
        await backend.waitUntilUploadStarts()
        auth.login(user: AppUser(id: "user-b", provider: .apple, avatarRevision: 1))
        let loadB = Task {
            await store.load(user: auth.currentUser, ownerKey: accountBKey)
        }
        await backend.waitUntilFetchStarts()
        await backend.finishUpload(with: userDTO(name: nil, revision: 2))

        let uploadSucceeded = await upload.value
        XCTAssertFalse(uploadSucceeded)
        XCTAssertEqual(auth.currentUser?.id, "user-b")
        XCTAssertEqual(store.phase, .loading)

        await backend.finishFetch(with: blue)
        await loadB.value
        XCTAssertEqual(store.image?.pngData(), UIImage(data: blue)?.pngData())
        XCTAssertEqual(store.phase, .idle)
    }

    func testAppearanceResolutionHonorsOverrideThenPreference() {
        XCTAssertEqual(RootView.resolvedColorScheme(testOverride: .light, mode: .dark), .light)
        XCTAssertEqual(RootView.resolvedColorScheme(testOverride: nil, mode: .dark), .dark)
        XCTAssertNil(RootView.resolvedColorScheme(testOverride: nil, mode: .system))
    }

    func testLegalLinksFailClosedUnlessTheyAreRealHTTPSURLs() {
        XCTAssertNil(AppConfig.validatedLegalURL(nil))
        XCTAssertNil(AppConfig.validatedLegalURL(""))
        XCTAssertNil(AppConfig.validatedLegalURL("http://qiuji.app/privacy"))
        XCTAssertNil(AppConfig.validatedLegalURL("https://example.com/privacy"))
        XCTAssertNil(AppConfig.validatedLegalURL("https://yourdomain.com/terms"))
        XCTAssertEqual(
            AppConfig.validatedLegalURL("https://qiuji.app/privacy")?.absoluteString,
            "https://qiuji.app/privacy"
        )
    }

    func testEntitlementSnapshotShowsExpirationAndLifetimeTruthfully() {
        let expiry = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2027, month: 2, day: 3)
        )!
        let subscription = SubscriptionManager.entitlementStatusLabel(
            productIDs: [StoreKitService.monthlyID],
            snapshots: [StoreEntitlementSnapshot(
                productID: StoreKitService.monthlyID,
                expirationDate: expiry,
                revocationDate: nil
            )],
            isPremium: true
        )
        XCTAssertEqual(subscription, "有效至 2027年2月3日")
        XCTAssertEqual(
            SubscriptionManager.entitlementStatusLabel(
                productIDs: [StoreKitService.lifetimeID], snapshots: [], isPremium: true
            ),
            "永久有效"
        )
    }

    func testRestoreLoadingTransitionsPreserveExistingEntitlementLabel() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        _ = try await session.buyProduct(identifier: StoreKitService.lifetimeID)
        _ = try await waitForEntitlement(StoreKitService.lifetimeID, present: true)
        let manager = SubscriptionManager(listenForUpdates: false, useDebugOverrides: false)
        let auth = AuthState()
        auth.login(user: AppUser(id: "storekit-test", provider: .apple))
        manager.bind(to: auth)
        await manager.checkEntitlements()
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(manager.entitlementStatusLabel, "永久有效")
        var loadingStates: [Bool] = []
        var statusLabels: [String] = []
        let observation = manager.$isLoading.dropFirst().sink { value in
            loadingStates.append(value)
            statusLabels.append(manager.entitlementStatusLabel)
        }
        defer { observation.cancel() }
        let restored = await manager.restorePurchases()
        XCTAssertTrue(restored)
        XCTAssertEqual(loadingStates, [true, false])
        XCTAssertEqual(statusLabels, ["永久有效", "永久有效"])
        XCTAssertFalse(manager.isLoading)
    }

    func testStoreKitConfigurationLoadsMonthlyYearlyAndLifetimeProducts() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()

        let products = try await Product.products(for: StoreKitService.allProductIDs)
        XCTAssertEqual(Set(products.map(\.id)), StoreKitService.allProductIDs)
        XCTAssertEqual(
            products.first(where: { $0.id == StoreKitService.monthlyID })?.type,
            .autoRenewable
        )
        XCTAssertEqual(
            products.first(where: { $0.id == StoreKitService.yearlyID })?.type,
            .autoRenewable
        )
        XCTAssertEqual(
            products.first(where: { $0.id == StoreKitService.lifetimeID })?.type,
            .nonConsumable
        )
    }

    func testStoreKitLocalSubscriptionsPurchaseAndExpire() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()

        let monthly = try await session.buyProduct(identifier: StoreKitService.monthlyID)
        XCTAssertEqual(monthly.productID, StoreKitService.monthlyID)
        let monthlySnapshots = try await waitForEntitlement(StoreKitService.monthlyID, present: true)
        XCTAssertNotNil(monthlySnapshots.first(where: { $0.productID == StoreKitService.monthlyID })?.expirationDate)

        try session.expireSubscription(productIdentifier: StoreKitService.monthlyID)
        _ = try await waitForEntitlement(StoreKitService.monthlyID, present: false)

        let yearly = try await session.buyProduct(identifier: StoreKitService.yearlyID)
        XCTAssertEqual(yearly.productID, StoreKitService.yearlyID)
        let yearlySnapshots = try await waitForEntitlement(StoreKitService.yearlyID, present: true)
        XCTAssertNotNil(yearlySnapshots.first(where: { $0.productID == StoreKitService.yearlyID })?.expirationDate)

        session.clearTransactions()
    }

    func testStoreKitLocalLifetimePurchaseSurvivesRestore() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()

        let lifetime = try await session.buyProduct(identifier: StoreKitService.lifetimeID)
        XCTAssertEqual(lifetime.productID, StoreKitService.lifetimeID)
        let purchased = try await waitForEntitlement(StoreKitService.lifetimeID, present: true)
        XCTAssertNil(purchased.first(where: { $0.productID == StoreKitService.lifetimeID })?.expirationDate)

        try await StoreKitService.shared.restorePurchases()
        let restored = try await waitForEntitlement(StoreKitService.lifetimeID, present: true)
        XCTAssertTrue(restored.contains(where: { $0.productID == StoreKitService.lifetimeID }))

        session.clearTransactions()
    }

    func testReminderPermissionDeniedDoesNotSchedule() async {
        let center = ReminderCenterMock(status: .denied)
        let result = await TrainingReminderScheduler(center: center).enable(at: .now)
        XCTAssertEqual(result, .permissionDenied)
        XCTAssertEqual(center.scheduleCount, 0)
    }

    func testReminderAllowedSchedulesAndDisableCancels() async {
        let center = ReminderCenterMock(status: .allowed)
        let scheduler = TrainingReminderScheduler(center: center)
        let result = await scheduler.enable(at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(result, .scheduled)
        XCTAssertEqual(center.scheduleCount, 1)
        scheduler.disable()
        XCTAssertEqual(center.cancelCount, 1)
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "V53ProfilePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func solidImage(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
    }

    private func waitForEntitlement(
        _ productID: String,
        present: Bool
    ) async throws -> [StoreEntitlementSnapshot] {
        var latest: [StoreEntitlementSnapshot] = []
        for _ in 0..<40 {
            latest = await StoreKitService.shared.currentEntitlements()
            if latest.contains(where: { $0.productID == productID }) == present {
                return latest
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("StoreKit entitlement \(productID) did not become present=\(present): \(latest)")
        return latest
    }
}

private struct ProfileAuthBackend: AuthSessionBackend {
    func fetchProfile() async throws -> UserDTO { throw AppError.authRequired }
    func logout() async {}
}

private struct EmptyCredentials: AuthCredentialStore {
    var hasRefreshToken: Bool { false }
    func clearAll() {}
}

private final class ProfileUpdateBackend: UserProfileBackend, @unchecked Sendable {
    let result: Result<UserDTO, Error>
    init(result: Result<UserDTO, Error>) { self.result = result }
    func updateProfile(_ update: UserProfileUpdate) async throws -> UserDTO { try result.get() }
}

private final class AvatarTestBackend: AvatarBackend, @unchecked Sendable {
    var uploadResult: Result<UserDTO, Error>
    init(uploadResult: Result<UserDTO, Error>) { self.uploadResult = uploadResult }
    func uploadAvatar(_ jpegData: Data) async throws -> UserDTO { try uploadResult.get() }
    func fetchAvatar(revision: Int) async throws -> Data { Data() }
    func deleteAvatar() async throws -> UserDTO { userDTO(name: nil) }
}

private actor DelayedAvatarUploadBackend: AvatarBackend {
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var uploadContinuation: CheckedContinuation<UserDTO, Never>?
    private var fetchStarted = false
    private var fetchWaiters: [CheckedContinuation<Void, Never>] = []
    private var fetchContinuation: CheckedContinuation<Data, Never>?

    func uploadAvatar(_ jpegData: Data) async throws -> UserDTO {
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        return await withCheckedContinuation { uploadContinuation = $0 }
    }

    func waitUntilUploadStarts() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func finishUpload(with dto: UserDTO) {
        uploadContinuation?.resume(returning: dto)
        uploadContinuation = nil
    }

    func fetchAvatar(revision: Int) async throws -> Data {
        fetchStarted = true
        fetchWaiters.forEach { $0.resume() }
        fetchWaiters.removeAll()
        return await withCheckedContinuation { fetchContinuation = $0 }
    }

    func waitUntilFetchStarts() async {
        if fetchStarted { return }
        await withCheckedContinuation { fetchWaiters.append($0) }
    }

    func finishFetch(with data: Data) {
        fetchContinuation?.resume(returning: data)
        fetchContinuation = nil
    }

    func deleteAvatar() async throws -> UserDTO { userDTO(name: nil) }
}

@MainActor
private final class ReminderCenterMock: TrainingReminderCenter {
    var status: TrainingReminderAuthorization
    var scheduleCount = 0
    var cancelCount = 0
    init(status: TrainingReminderAuthorization) { self.status = status }
    func authorization() async -> TrainingReminderAuthorization { status }
    func requestAuthorization() async throws -> Bool { status == .allowed }
    func schedule(hour: Int, minute: Int) async throws { scheduleCount += 1 }
    func cancel() { cancelCount += 1 }
}

private struct TestFailure: LocalizedError {
    var errorDescription: String? { "测试失败" }
}

private func userDTO(name: String?, revision: Int? = nil) -> UserDTO {
    UserDTO(id: "user-a", displayName: name, email: nil, provider: "apple",
            avatarRevision: revision, preferredSport: "chinese8", skillLevel: "beginner",
            yearsPlaying: "lessThan1", weeklyGoalDays: 3)
}
