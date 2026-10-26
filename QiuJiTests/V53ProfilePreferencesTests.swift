import XCTest
import UIKit
import StoreKit
import StoreKitTest
import Combine
@testable import QiuJi

@MainActor
final class V53ProfilePreferencesTests: XCTestCase {
    func testDailySpinTransparencyDefaultsAndPersistsIncludingEndpoints() {
        let defaults = isolatedDefaults()
        let preferences = UserPreferences(defaults: defaults)
        XCTAssertEqual(preferences.dailySpinDiscTransparency, 0.5)
        for value in [0.0, 1.0, 0.73] {
            preferences.dailySpinDiscTransparency = value
            XCTAssertEqual(UserPreferences(defaults: defaults).dailySpinDiscTransparency, value)
        }
    }

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
        let observation = manager.$isTransacting.dropFirst().sink { value in
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

    func testDefaultGameFollowsSportUntilManuallySelectedAndSurvivesRestart() {
        let defaults = isolatedDefaults()
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.dailyClearanceGame, .chineseEightBall)
        prefs.synchronizeDefaultGame(with: .nineBall)
        XCTAssertEqual(prefs.dailyClearanceGame, .nineBall)
        prefs.synchronizeDefaultGame(with: .both)
        XCTAssertEqual(prefs.dailyClearanceGame, .nineBall)
        let bothRestored = UserPreferences(defaults: defaults)
        bothRestored.synchronizeDefaultGame(with: .both)
        XCTAssertEqual(bothRestored.dailyClearanceGame, .nineBall)
        prefs.synchronizeDefaultGame(with: .chinese8)
        XCTAssertEqual(prefs.dailyClearanceGame, .chineseEightBall)
        // Even selecting the currently displayed value is an explicit choice.
        prefs.selectDailyClearanceGame(.chineseEightBall)
        prefs.synchronizeDefaultGame(with: .nineBall)
        XCTAssertEqual(prefs.dailyClearanceGame, .chineseEightBall)
        let restored = UserPreferences(defaults: defaults)
        restored.synchronizeDefaultGame(with: .nineBall)
        XCTAssertEqual(restored.dailyClearanceGame, .chineseEightBall)
    }

    func testDefaultGamePreservesLegacyExplicitSelection() {
        let defaults = isolatedDefaults()
        defaults.set(DailyClearanceGame.nineBall.rawValue, forKey: DailyClearanceStoreKey.preferredGame)
        let prefs = UserPreferences(defaults: defaults)
        prefs.synchronizeDefaultGame(with: .chinese8)
        XCTAssertEqual(prefs.dailyClearanceGame, .nineBall)
    }

    func testDefaultGameUsesCurrentOwnerProfileAfterLegacyMigrationAndAccountRestore() async {
        let defaults = isolatedDefaults()
        defaults.set(PreferredSport.nineBall.rawValue, forKey: "preferredSport")
        let prefs = UserPreferences(defaults: defaults)
        let guestKey = DeviceGuestIdentity.ownerKey(in: defaults)
        prefs.synchronizeDefaultGame(ownerKey: guestKey, user: nil)
        XCTAssertEqual(prefs.dailyClearanceGame, .nineBall)
        XCTAssertNil(defaults.object(forKey: "preferredSport"))
        let account = AppUser(id: "user-a", provider: .apple,
                              preferredSport: PreferredSport.chinese8.rawValue)
        prefs.synchronizeDefaultGame(ownerKey: OwnerKey.account("user-a"), user: account)
        XCTAssertEqual(prefs.dailyClearanceGame, .chineseEightBall)
        // Logging out restores the guest's choice, not the previous account's profile.
        prefs.synchronizeDefaultGame(ownerKey: guestKey, user: nil)
        XCTAssertEqual(prefs.dailyClearanceGame, .nineBall)
        let restored = UserPreferences(defaults: defaults)
        restored.synchronizeDefaultGame(ownerKey: guestKey, user: nil)
        XCTAssertEqual(restored.dailyClearanceGame, .nineBall)
    }

    func testGuestSportSaveUpdatesDefaultAndFailedAccountSaveDoesNot() async {
        let defaults = isolatedDefaults()
        let prefs = UserPreferences(defaults: defaults)
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.loginAnonymously()
        let guest = OwnerProfileStore(ownerKey: owner.guestOwnerKey, defaults: defaults)
        await guest.setPreferredSport(.nineBall, authState: auth, preferences: prefs)
        XCTAssertEqual(prefs.dailyClearanceGame, .nineBall)
        let accountUser = AppUser(id: "user-a", provider: .apple,
                                  preferredSport: PreferredSport.nineBall.rawValue)
        auth.login(user: accountUser)
        let backend = ProfileUpdateBackend(result: .failure(TestFailure()))
        let account = OwnerProfileStore(ownerKey: OwnerKey.account("user-a"), defaults: defaults,
                                        backend: backend)
        account.load(from: accountUser)
        await account.setPreferredSport(.chinese8, authState: auth, preferences: prefs)
        XCTAssertEqual(account.preferredSport, .nineBall)
        XCTAssertEqual(prefs.dailyClearanceGame, .nineBall)
        XCTAssertNotNil(account.errorMessage)
    }

    func testProfileBasicsGuestPersistenceClearingAndOwnerIsolation() async {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(), defaults: defaults, ownerContext: owner)
        auth.loginAnonymously()
        let store = OwnerProfileStore(ownerKey: owner.guestOwnerKey, defaults: defaults)
        let genderSaved = await store.setGender(.female, authState: auth)
        let birthdaySaved = await store.setBirthDate("2000-02-29", authState: auth)
        XCTAssertTrue(genderSaved); XCTAssertTrue(birthdaySaved)
        let restored = OwnerProfileStore(ownerKey: owner.guestOwnerKey, defaults: defaults)
        XCTAssertEqual(restored.gender, .female); XCTAssertEqual(restored.birthDate, "2000-02-29")
        let account = OwnerProfileStore(ownerKey: OwnerKey.account("other"), defaults: defaults)
        XCTAssertEqual(account.gender, .unspecified); XCTAssertNil(account.birthDate)
        _ = await restored.setGender(.unspecified, authState: auth)
        _ = await restored.setBirthDate(nil, authState: auth)
        let cleared = OwnerProfileStore(ownerKey: owner.guestOwnerKey, defaults: defaults)
        XCTAssertEqual(cleared.gender, .unspecified); XCTAssertNil(cleared.birthDate)
        let invalid = await cleared.setBirthDate("2001-02-29", authState: auth)
        XCTAssertFalse(invalid); XCTAssertNil(cleared.birthDate)
    }

    func testProfileBasicsServerTruthAndFailurePreserveExistingValues() async {
        let defaults = isolatedDefaults()
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(), defaults: defaults,
                             ownerContext: CurrentOwnerContext(defaults: defaults))
        auth.login(user: AppUser(id: "user-a", provider: .apple, gender: "male", birthDate: "1990-01-01"))
        var response = userDTO(name: "服务端昵称")
        response.gender = "female"; response.birthDate = "2000-02-29"
        let store = OwnerProfileStore(ownerKey: OwnerKey.account("user-a"), defaults: defaults,
                                      backend: ProfileUpdateBackend(result: .success(response)))
        store.load(from: auth.currentUser)
        let saved = await store.setBirthDate("1999-01-01", authState: auth)
        XCTAssertTrue(saved); XCTAssertEqual(store.birthDate, "2000-02-29")
        XCTAssertEqual(store.gender, .female); XCTAssertEqual(auth.currentUser?.birthDate, "2000-02-29")
        let failing = OwnerProfileStore(ownerKey: store.ownerKey, defaults: defaults,
                                        backend: ProfileUpdateBackend(result: .failure(TestFailure())))
        failing.load(from: auth.currentUser)
        let failed = await failing.setBirthDate(nil, authState: auth)
        XCTAssertFalse(failed); XCTAssertEqual(failing.birthDate, "2000-02-29")
        let genderFailed = await failing.setGender(.male, authState: auth)
        XCTAssertFalse(genderFailed); XCTAssertEqual(failing.gender, .female)
        OwnerProfileStore.removeLocalProfile(ownerKey: store.ownerKey, in: defaults)
        let removed = OwnerProfileStore(ownerKey: store.ownerKey, defaults: defaults)
        XCTAssertNil(removed.birthDate); XCTAssertEqual(removed.gender, .unspecified)
    }

    func testProfileBasicsPartialPayloadAndLegacyDTOCompatibility() throws {
        func json(_ update: UserProfileUpdate) throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(update)) as? [String: Any])
        }
        let nameOnly = try json(UserProfileUpdate(displayName: "昵称"))
        XCTAssertNil(nameOnly["gender"]); XCTAssertNil(nameOnly["birthDate"])
        let gender = try json(UserProfileUpdate(gender: .male))
        XCTAssertEqual(gender["gender"] as? String, "male"); XCTAssertEqual(gender.count, 1)
        let cleared = try json(UserProfileUpdate(gender: .unspecified, updatesBirthDate: true))
        XCTAssertTrue(cleared["gender"] is NSNull); XCTAssertTrue(cleared["birthDate"] is NSNull)
        let dto = try JSONDecoder().decode(UserDTO.self, from: Data(#"{"id":"old","provider":"apple","displayName":"保留昵称"}"#.utf8))
        XCTAssertNil(dto.birthDate); XCTAssertNil(dto.gender)
        XCTAssertEqual(AppUser(dto: dto).displayName, "保留昵称")
    }

    func testProfileBirthdayUsesCivilDatesAndWholeYears() throws {
        let calendar = Calendar(identifier: .gregorian)
        let before = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 16)))
        let birthday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17)))
        XCTAssertEqual(ProfileBirthday.age("2000-10-17", now: before), 25)
        XCTAssertEqual(ProfileBirthday.age("2000-10-17", now: birthday), 26)
        XCTAssertEqual(ProfileBirthday.age("2026-10-17", now: birthday), 0)
        XCTAssertNotNil(ProfileBirthday.date("2000-02-29", now: birthday))
        for invalid in ["2001-02-29", "2000-2-1", "1899-12-31", "2026-10-18"] {
            XCTAssertNil(ProfileBirthday.date(invalid, now: birthday), invalid)
        }
        XCTAssertEqual(ProfileBirthday.string(birthday), "2026-10-17")
    }

    func testFirstRunDetectsLegacyGuestsSettingsStoresAndCredentials() {
        func existing(_ keys: Set<String> = [], completed: Bool = false,
                      store: Bool = false, credentials: Bool = false) -> Bool {
            FirstRunProfileFlow.hasExistingInstallation(persistedKeys: keys,
                completedOnboarding: completed, hasStore: store, hasCredentials: credentials)
        }
        XCTAssertFalse(existing(["AppleLanguages", "NSLanguages"]))
        for key in [DeviceGuestIdentity.defaultsKey, "preferredSport", "appearanceMode",
                    "ownerProfile.guest:old.birthDate", "hasCompletedOnboarding"] {
            XCTAssertTrue(existing([key]), key)
        }
        XCTAssertTrue(existing(store: true))
        XCTAssertTrue(existing(credentials: true))
        XCTAssertTrue(existing(completed: true))
    }

    func testFirstRunResumesAndSkipIsTerminalDespiteStartupWrites() {
        let defaults = isolatedDefaults()
        let flow = FirstRunProfileFlow(defaults: defaults, hasExistingData: false)
        XCTAssertEqual(flow.stage, .introduction)
        _ = DeviceGuestIdentity.id(in: defaults)
        XCTAssertEqual(FirstRunProfileFlow(defaults: defaults, hasExistingData: true).stage, .introduction)
        flow.finishIntroduction()
        let resumed = FirstRunProfileFlow(defaults: defaults, hasExistingData: true)
        XCTAssertEqual(resumed.stage, .profile)
        let profileBefore = defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("ownerProfile.") }
        resumed.finish()
        resumed.finishIntroduction()
        XCTAssertEqual(FirstRunProfileFlow(defaults: defaults, hasExistingData: false).stage, .completed)
        XCTAssertEqual(profileBefore as NSDictionary,
                       defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("ownerProfile.") } as NSDictionary)
    }

    func testFirstRunUpgradeOnlyWritesProgressMarker() {
        let defaults = isolatedDefaults()
        defaults.set("已有昵称", forKey: "ownerProfile.guest:old.displayName")
        defaults.set("3d", forKey: "table.preferences.savedView")
        defaults.set(false, forKey: "hasCompletedOnboarding")
        let before = defaults.dictionaryRepresentation()
        let flow = FirstRunProfileFlow(defaults: defaults, hasExistingData: true)
        XCTAssertEqual(flow.stage, .completed)
        var after = defaults.dictionaryRepresentation()
        after.removeValue(forKey: FirstRunProfileFlow.progressKey)
        XCTAssertEqual(before as NSDictionary, after as NSDictionary)
    }

    func testFirstRunReturningCredentialsSuppressPendingProfileEvenOffline() {
        let defaults = isolatedDefaults()
        let flow = FirstRunProfileFlow(defaults: defaults, hasExistingData: false)
        flow.finishIntroduction()
        let restored = FirstRunProfileFlow(defaults: defaults, hasExistingData: true, hasCredentials: true)
        XCTAssertEqual(restored.stage, .completed)
        XCTAssertEqual(FirstRunProfileFlow(defaults: defaults, hasExistingData: true).stage, .completed)
    }

    func testInitialProfileOnlySavesChoicesAndPreservesExistingFieldsAndSettings() {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.loginAnonymously()
        let prefix = "ownerProfile.\(owner.ownerKey)."
        defaults.set("旧昵称", forKey: prefix + "displayName")
        defaults.set("2000-01-01", forKey: prefix + "birthDate")
        defaults.set(ProfileGender.female.rawValue, forKey: prefix + "gender")
        defaults.set(YearsPlaying.fivePlus.rawValue, forKey: prefix + "yearsPlaying")
        defaults.set("3d", forKey: "table.preferences.savedView")
        defaults.set(DailyClearanceGame.chineseEightBall.rawValue, forKey: DailyClearanceStoreKey.preferredGame)
        let prefs = UserPreferences(defaults: defaults)
        let store = OwnerProfileStore(ownerKey: owner.ownerKey, defaults: defaults)
        XCTAssertTrue(store.saveInitialProfile(InitialProfileDraft(displayName: "新昵称",
            preferredSport: .nineBall, yearsPlaying: .lessThan1), authState: auth, preferences: prefs))
        let restored = OwnerProfileStore(ownerKey: owner.ownerKey, defaults: defaults)
        XCTAssertEqual(restored.displayName, "旧昵称")
        XCTAssertEqual(restored.preferredSport, .nineBall)
        XCTAssertEqual(restored.yearsPlaying, .fivePlus)
        XCTAssertEqual(restored.birthDate, "2000-01-01")
        XCTAssertEqual(restored.gender, .female)
        XCTAssertNil(defaults.object(forKey: prefix + "skillLevel"))
        XCTAssertNil(defaults.object(forKey: prefix + "weeklyGoalDays"))
        XCTAssertEqual(prefs.dailyClearanceGame, .chineseEightBall)
        XCTAssertEqual(defaults.string(forKey: "table.preferences.savedView"), "3d")
    }

    func testInitialProfileEmptyDraftWritesNothingAndInvalidNameIsAtomic() {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.loginAnonymously()
        let prefs = UserPreferences(defaults: defaults)
        let store = OwnerProfileStore(ownerKey: owner.ownerKey, defaults: defaults)
        let before = defaults.dictionaryRepresentation()
        XCTAssertTrue(store.saveInitialProfile(InitialProfileDraft(), authState: auth, preferences: prefs))
        XCTAssertEqual(defaults.dictionaryRepresentation() as NSDictionary, before as NSDictionary)
        XCTAssertFalse(store.saveInitialProfile(InitialProfileDraft(displayName: String(repeating: "球", count: 21),
            preferredSport: .nineBall), authState: auth, preferences: prefs))
        XCTAssertEqual(defaults.dictionaryRepresentation() as NSDictionary, before as NSDictionary)
    }

    func testInitialProfileRestoredAccountRejectsStaleGuestDraft() {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        let prefs = UserPreferences(defaults: defaults)
        let guest = OwnerProfileStore(ownerKey: owner.guestOwnerKey, defaults: defaults)
        auth.login(user: AppUser(id: "returning", provider: .apple, displayName: "账号旧昵称"))
        let before = defaults.dictionaryRepresentation()
        XCTAssertFalse(guest.saveInitialProfile(InitialProfileDraft(displayName: "游客草稿",
            preferredSport: .nineBall), authState: auth, preferences: prefs))
        XCTAssertEqual(defaults.dictionaryRepresentation() as NSDictionary, before as NSDictionary)
        XCTAssertEqual(auth.currentUser?.displayName, "账号旧昵称")
    }

    func testInitialProfileNewChoicesPersistAndInferDefaultGame() {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.loginAnonymously()
        let prefs = UserPreferences(defaults: defaults)
        let store = OwnerProfileStore(ownerKey: owner.ownerKey, defaults: defaults)
        XCTAssertTrue(store.saveInitialProfile(InitialProfileDraft(displayName: " 新球友 ",
            preferredSport: .nineBall, skillLevel: .intermediate, yearsPlaying: .oneToThree),
            authState: auth, preferences: prefs))
        let restored = OwnerProfileStore(ownerKey: owner.ownerKey, defaults: defaults)
        XCTAssertEqual(restored.displayName, "新球友")
        XCTAssertEqual(restored.preferredSport, .nineBall)
        XCTAssertEqual(restored.skillLevel, .intermediate)
        XCTAssertEqual(restored.yearsPlaying, .oneToThree)
        XCTAssertEqual(prefs.dailyClearanceGame, .nineBall)
        XCTAssertNil(defaults.object(forKey: DailyClearanceStoreKey.preferredGame))
    }

    func testInitialFourStepProfilePersistsExplicitFieldsWithoutOverwriting() {
        let defaults = isolatedDefaults()
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: owner)
        auth.loginAnonymously()
        let prefs = UserPreferences(defaults: defaults)
        let store = OwnerProfileStore(ownerKey: owner.ownerKey, defaults: defaults)
        let before = defaults.dictionaryRepresentation()
        XCTAssertFalse(store.saveInitialProfile(InitialProfileDraft(preferredSport: .zhuifen,
            gender: .male, birthDate: "2999-01-01"), authState: auth, preferences: prefs))
        XCTAssertEqual(before as NSDictionary, defaults.dictionaryRepresentation() as NSDictionary)
        XCTAssertTrue(store.saveInitialProfile(InitialProfileDraft(preferredSport: .zhuifen,
            yearsPlaying: .threeToFive, gender: .male, birthDate: "1996-06-18"), authState: auth, preferences: prefs))
        let restored = OwnerProfileStore(ownerKey: owner.ownerKey, defaults: defaults)
        XCTAssertEqual(restored.preferredSport, .zhuifen)
        XCTAssertEqual(restored.gender, .male)
        XCTAssertEqual(restored.birthDate, "1996-06-18")
        XCTAssertEqual(restored.yearsPlaying, .threeToFive)
        XCTAssertNil(DailyClearanceGame.initialDefault(for: .zhuifen))
        XCTAssertNil(DailyClearanceGame.initialDefault(for: .other))
        XCTAssertTrue(store.saveInitialProfile(InitialProfileDraft(preferredSport: .other,
            gender: .female, birthDate: "2001-01-01"), authState: auth, preferences: prefs))
        XCTAssertEqual(store.preferredSport, .zhuifen)
        XCTAssertEqual(store.gender, .male)
        XCTAssertEqual(store.birthDate, "1996-06-18")
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

@MainActor
final class TablePreferencesStoreTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "TablePreferencesStoreTests." + UUID().uuidString
        let result = UserDefaults(suiteName: name)!
        addTeardownBlock { result.removePersistentDomain(forName: name) }
        return result
    }
    func testRehearsalDefaultsOffAndOnlyUsesGlobalSetting() throws {
        let d = defaults()
        XCTAssertFalse(TablePreferencesStore(defaults: d).general.enabled(.rehearsal))
        // Legacy page overrides must not become hidden settings after the UI is removed.
        let archive: [String: Any] = ["version": 1, "general": ["rehearsal": 0],
            "pages": [TablePreferencePage.freePlay.rawValue: ["rehearsal": 1, "grid": 1]]]
        d.set(try JSONSerialization.data(withJSONObject: archive), forKey: TablePreferencesStore.storageKey)
        let store = TablePreferencesStore(defaults: d)
        XCTAssertFalse(store.snapshot(for: .freePlay).enabled(.rehearsal))
        XCTAssertTrue(store.snapshot(for: .freePlay).enabled(.grid))
        store.apply(.rehearsal, value: 1, to: .freePlay)
        XCTAssertFalse(store.snapshot(for: .freePlay).enabled(.rehearsal))
        store.apply(.rehearsal, value: 1)
        let restarted = TablePreferencesStore(defaults: d)
        XCTAssertTrue(restarted.general.enabled(.rehearsal))
        XCTAssertTrue(restarted.snapshot(for: .freePlay).enabled(.rehearsal))
        for page: TablePreferencePage in [.accuracy2D, .accuracy3D, .separationPractice2D,
            .separationPractice3D, .twoBallPractice2D, .twoBallPractice3D] {
            XCTAssertFalse(restarted.snapshot(for: page).enabled(.rehearsal), "Assessment always strokes directly")
        }
    }
    func testLocalIsolationRestartAndSameValueGlobalOverride() {
        let d = defaults(), s = TablePreferencesStore(defaults: defaults())
        XCTAssertFalse(s.snapshot(for: .freePlay).enabled(.view3D))
        let first = TablePreferencesStore(defaults: d)
        first.apply(.view3D, value: 1, to: .freePlay)
        XCTAssertFalse(first.snapshot(for: .dailyClearance).enabled(.view3D))
        let reopened = TablePreferencesStore(defaults: d)
        XCTAssertTrue(reopened.snapshot(for: .freePlay).enabled(.view3D))
        reopened.apply(.view3D, value: 1)
        reopened.apply(.view3D, value: 0, to: .freePlay)
        reopened.apply(.grid, value: 1, to: .freePlay)
        let revision = reopened.revision
        reopened.reapply(.view3D)
        XCTAssertGreaterThan(reopened.revision, revision)
        XCTAssertTrue(reopened.snapshot(for: .freePlay).enabled(.view3D))
        XCTAssertTrue(reopened.snapshot(for: .freePlay).enabled(.grid))
        XCTAssertFalse(reopened.snapshot(for: .sceneAiming2D).enabled(.view3D))
    }
    func testLegacyMigrationSplitsSharedKeysAndNeverResurrectsThem() {
        let d = defaults()
        d.set(true, forKey: "snakePractice.view3D")
        d.set(0.73, forKey: "bankKick.spinTransparency")
        d.set(true, forKey: "composer.3DTrajectoryHidden")
        d.set(true, forKey: "showAimCloseup")
        d.set("ongoing-game", forKey: "dailyClearance.testDraft")
        let s = TablePreferencesStore(defaults: d)
        XCTAssertTrue(s.snapshot(for: .snakePractice).enabled(.view3D))
        XCTAssertEqual(s.snapshot(for: .bankShot)[.transparency], 0.73)
        XCTAssertEqual(s.snapshot(for: .diamondSystem)[.transparency], 0.73)
        XCTAssertFalse(s.snapshot(for: .drillTryout).enabled(.shows3DTrajectory))
        XCTAssertTrue(s.snapshot(for: .freePlay).enabled(.closeup))
        s.apply(.transparency, value: 0.2, to: .bankShot)
        XCTAssertEqual(s.snapshot(for: .diamondSystem)[.transparency], 0.73)
        s.apply(.transparency, value: 0.5)
        s.apply(.view3D, value: 0)
        let restarted = TablePreferencesStore(defaults: d)
        XCTAssertEqual(restarted.snapshot(for: .bankShot)[.transparency], 0.5)
        XCTAssertFalse(restarted.snapshot(for: .snakePractice).enabled(.view3D))
        XCTAssertTrue(d.bool(forKey: "snakePractice.view3D"))
        XCTAssertEqual(d.string(forKey: "dailyClearance.testDraft"), "ongoing-game")
    }
    func testTrajectoryVisibilityPreservesDetailsAndVisibleSelectionUnhides() {
        let s = TablePreferencesStore(defaults: defaults())
        s.apply(.trajectory, value: 2, to: .freePlay)
        s.apply(.trajectory, value: 1, to: .dailyClearance)
        s.apply(.shows3DTrajectory, value: 0)
        s.reapply(.shows3DTrajectory)
        XCTAssertEqual(s.snapshot(for: .freePlay).trajectoryDetail, .minimal)
        s.apply(.shows3DTrajectory, value: 1)
        XCTAssertEqual(s.snapshot(for: .dailyClearance).trajectoryDetail, .core)
        s.apply(.shows3DTrajectory, value: 0, to: .freePlay)
        s.reapply(.trajectory)
        for page in TablePreferencePage.allCases where page.fields.contains(.trajectory) {
            XCTAssertEqual(s.snapshot(for: page).trajectoryDetail, .full)
            XCTAssertTrue(s.snapshot(for: page).enabled(.shows3DTrajectory))
        }
        XCTAssertFalse(TablePreferencePage.separationAngleAtlas.fields.contains(.trajectory))
    }
    func testEveryFieldOverwritesOnlySupportedPageField() {
        let s = TablePreferencesStore(defaults: defaults())
        for field in TablePreferenceField.allCases {
            for page in TablePreferencePage.allCases where page.fields.contains(field) {
                s.apply(field, value: 1, to: page)
            }
            s.apply(field, value: field.initialValue)
            for page in TablePreferencePage.allCases where page.fields.contains(field) {
                XCTAssertEqual(s.snapshot(for: page)[field], field.initialValue, "\(page)/\(field)")
            }
        }
    }
    func testInvalidMigrationAndInputStayFiniteAndLegal() {
        let d = defaults()
        d.set(Double.nan, forKey: "freePlay.spinDiscTransparency")
        d.set(99, forKey: "trajectoryDetail")
        let s = TablePreferencesStore(defaults: d)
        XCTAssertEqual(s.snapshot(for: .freePlay)[.transparency], 0.5)
        XCTAssertEqual(s.general.trajectoryDetail, .full)
        s.apply(.transparency, value: 2)
        XCTAssertEqual(s.general[.transparency], 1)
        s.apply(.trajectory, value: .infinity)
        XCTAssertEqual(s.general.trajectoryDetail, .full)
    }
}

extension V53ProfilePreferencesTests {
    private func proTestAuth() -> AuthState {
        let defaults = isolatedDefaults()
        let auth = AuthState(backend: ProfileAuthBackend(), credentials: EmptyCredentials(),
                             defaults: defaults, ownerContext: CurrentOwnerContext(defaults: defaults))
        auth.login(user: AppUser(id: "pro-purchase-tests", provider: .apple))
        return auth
    }

    func testProPurchaseCancelledPendingAndConfirmingAreNotUnlocks() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        defer { session.clearTransactions() }
        let products = try await Product.products(for: [StoreKitService.lifetimeID])
        let product = try XCTUnwrap(products.first)
        for outcome in [SubscriptionManager.PurchaseOutcome.cancelled, .pending, .confirming] {
            let manager = SubscriptionManager(entitlementLoader: { [] }, listenForUpdates: false,
                useDebugOverrides: false, purchaseOperation: { _ in
                    if outcome == .cancelled { throw CancellationError() }
                    if outcome == .pending { throw StoreError.purchasePending }
                })
            let auth = proTestAuth()
            manager.bind(to: auth)
            await manager.checkEntitlements()
            let result = await manager.purchaseResult(product)
            XCTAssertEqual(result, outcome)
            XCTAssertFalse(manager.isPremium)
            XCTAssertNil(manager.errorMessage)
            XCTAssertFalse(manager.isTransacting)
            if outcome != .cancelled {
                XCTAssertFalse(manager.canPurchase(productID: product.id))
                XCTAssertFalse(manager.canPurchase(productID: StoreKitService.monthlyID))
                manager.resetWaitingPurchaseAfterCancellation()
                if outcome == .pending {
                    XCTAssertNil(manager.awaitingProductID)
                    XCTAssertTrue(manager.canPurchase(productID: product.id))
                } else {
                    XCTAssertEqual(manager.awaitingProductID, product.id)
                    XCTAssertFalse(manager.canPurchase(productID: product.id), "Completed purchases must refresh instead of buying again")
                }
                XCTAssertFalse(manager.isPremium, "Acknowledging cancellation cannot grant access")
            }
        }
        XCTAssertEqual(session.allTransactions().count, 0, "Injected outcomes never fabricate an Apple purchase")
    }

    func testProPurchaseAccountChangeAndConcurrentCallCannotReportSuccess() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        defer { session.clearTransactions() }
        let products = try await Product.products(for: [StoreKitService.lifetimeID])
        let product = try XCTUnwrap(products.first)
        var release: CheckedContinuation<Void, Never>?
        let entered = expectation(description: "purchase entered")
        let manager = SubscriptionManager(entitlementLoader: { [] }, listenForUpdates: false,
            useDebugOverrides: false, purchaseOperation: { _ in
                await withCheckedContinuation { continuation in release = continuation; entered.fulfill() }
            })
        let auth = proTestAuth()
        manager.bind(to: auth)
        let pending = Task { await manager.purchaseResult(product) }
        await fulfillment(of: [entered], timeout: 3)
        let duplicate = await manager.purchaseResult(product)
        XCTAssertEqual(duplicate, .busy)
        auth.login(user: AppUser(id: "other-purchase-user", provider: .apple))
        release?.resume()
        let result = await pending.value
        XCTAssertEqual(result, .sessionChanged)
        XCTAssertFalse(manager.isPremium)
    }

    func testProStoreKitPendingApprovalAndRevocation() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        session.askToBuyEnabled = true
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let products = try await Product.products(for: [StoreKitService.lifetimeID])
        let product = try XCTUnwrap(products.first)
        let manager = SubscriptionManager(useDebugOverrides: false)
        let auth = proTestAuth()
        manager.bind(to: auth)
        await manager.checkEntitlements()
        let result = await manager.purchaseResult(product)
        XCTAssertEqual(result, .pending)
        XCTAssertFalse(manager.isPremium)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        _ = try await waitForEntitlement(product.id, present: true)
        await manager.checkEntitlements()
        XCTAssertTrue(manager.isPremium)
        XCTAssertNil(manager.awaitingProductID)
        try session.refundTransaction(identifier: transaction.identifier)
        _ = try await waitForEntitlement(product.id, present: false)
        await manager.checkEntitlements()
        XCTAssertFalse(manager.isPremium)
    }

    func testProStoreKitDeclinedApprovalDoesNotUnlockOrDuplicatePurchase() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        session.askToBuyEnabled = true
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let products = try await Product.products(for: [StoreKitService.lifetimeID])
        let product = try XCTUnwrap(products.first)
        let manager = SubscriptionManager(useDebugOverrides: false)
        let auth = proTestAuth()
        manager.bind(to: auth)
        await manager.checkEntitlements()
        let result = await manager.purchaseResult(product)
        XCTAssertEqual(result, .pending)
        let duplicate = await manager.purchaseResult(product)
        XCTAssertNotEqual(duplicate, .unlocked)
        XCTAssertEqual(manager.purchaseOutcome, .pending)
        XCTAssertEqual(session.allTransactions().count, 1)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.declineAskToBuyTransaction(identifier: transaction.identifier)
        await manager.checkEntitlements()
        XCTAssertFalse(manager.isPremium)
        XCTAssertTrue(manager.purchasedProductIDs.isEmpty)
        manager.resetWaitingPurchaseAfterCancellation()
        XCTAssertNil(manager.awaitingProductID)
        XCTAssertTrue(manager.canPurchase(productID: product.id))
    }

    func testProStoreKitMonthlyCanUpgradeLifetimeAndRestoreBoth() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        defer { session.clearTransactions() }
        _ = try await session.buyProduct(identifier: StoreKitService.monthlyID)
        _ = try await waitForEntitlement(StoreKitService.monthlyID, present: true)
        let manager = SubscriptionManager(listenForUpdates: false, useDebugOverrides: false)
        let auth = proTestAuth()
        manager.bind(to: auth)
        await manager.checkEntitlements()
        XCTAssertTrue(manager.canPurchase(productID: StoreKitService.lifetimeID))
        XCTAssertFalse(manager.canPurchase(productID: StoreKitService.yearlyID))
        let products = try await Product.products(for: [StoreKitService.lifetimeID])
        let product = try XCTUnwrap(products.first)
        let result = await manager.purchaseResult(product)
        XCTAssertEqual(result, .unlocked)
        XCTAssertTrue(manager.purchasedProductIDs.contains(StoreKitService.monthlyID))
        XCTAssertTrue(manager.purchasedProductIDs.contains(StoreKitService.lifetimeID))
        XCTAssertFalse(manager.canPurchase(productID: product.id))
        let restored = await manager.restorePurchases()
        XCTAssertTrue(restored)
        XCTAssertEqual(manager.entitlementStatusLabel, "永久有效")
    }
}
