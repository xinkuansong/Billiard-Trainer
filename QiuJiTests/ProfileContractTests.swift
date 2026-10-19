import XCTest
@testable import QiuJi

final class ProfileContractTests: XCTestCase {

    func testAgeUsesCurrentDateAndBirthdayBoundary() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date.now
        let currentYear = calendar.component(.year, from: now)
        XCTAssertEqual(ProfileBirthday.age("2000-01-01", now: now), currentYear - 2000)
        let before = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 23, minute: 59)))
        let birthday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 18)))
        XCTAssertEqual(ProfileBirthday.age("2000-10-18", now: before), 25)
        XCTAssertEqual(ProfileBirthday.age("2000-10-18", now: birthday), 26)
        XCTAssertNil(ProfileBirthday.age("2026-10-19", now: birthday))
    }

    func testUserDTODecodesNormalizedProfileShape() throws {
        let data = Data("""
        {
          "id": "507f1f77bcf86cd799439011",
          "displayName": "球徒",
          "email": null,
          "provider": "apple",
          "avatarRevision": 3,
          "preferredSport": "chinese8",
          "skillLevel": "intermediate",
          "yearsPlaying": "threeToFive",
          "weeklyGoalDays": 4
        }
        """.utf8)

        let user = try JSONDecoder().decode(UserDTO.self, from: data)

        XCTAssertEqual(user.id, "507f1f77bcf86cd799439011")
        XCTAssertEqual(user.displayName, "球徒")
        XCTAssertEqual(user.avatarRevision, 3)
        XCTAssertEqual(user.preferredSport, "chinese8")
        XCTAssertEqual(user.skillLevel, "intermediate")
        XCTAssertEqual(user.yearsPlaying, "threeToFive")
        XCTAssertEqual(user.weeklyGoalDays, 4)
    }

    func testUserDTODecodesLegacyResponseWithoutNewOptionalFields() throws {
        let data = Data("""
        {
          "id": "legacy-user",
          "displayName": null,
          "email": null,
          "provider": "apple"
        }
        """.utf8)

        let user = try JSONDecoder().decode(UserDTO.self, from: data)

        XCTAssertNil(user.avatarRevision)
        XCTAssertNil(user.preferredSport)
        XCTAssertNil(user.skillLevel)
        XCTAssertNil(user.yearsPlaying)
        XCTAssertNil(user.weeklyGoalDays)
    }

    func testProfileUpdateEncodesOnlySpecifiedFields() throws {
        let update = UserProfileUpdate(displayName: "球徒", weeklyGoalDays: 5)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(update)) as? [String: Any]
        )

        XCTAssertEqual(object.count, 2)
        XCTAssertEqual(object["displayName"] as? String, "球徒")
        XCTAssertEqual(object["weeklyGoalDays"] as? Int, 5)
        XCTAssertNil(object["preferredSport"])
    }
}

@MainActor
final class InitialProfileImportTests: XCTestCase {
    private actor ImportBackend: InitialProfileImportBackend {
        var calls = 0
        var failNext = false
        var delay: UInt64 = 0
        func configure(fail: Bool = false, delay: UInt64 = 0) { failNext = fail; self.delay = delay }
        func importInitialProfile(_ proposal: InitialProfileImport) async throws -> UserDTO {
            calls += 1
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            if failNext { failNext = false; throw AppError.networkError("offline") }
            return UserDTO(id: proposal.accountID, displayName: "测试", email: nil, provider: "apple",
                           avatarRevision: nil, preferredSport: proposal.fields["preferredSport"],
                           skillLevel: nil, yearsPlaying: proposal.fields["yearsPlaying"], weeklyGoalDays: nil,
                           gender: proposal.fields["gender"], birthDate: proposal.fields["birthDate"])
        }
    }
    private struct Credentials: AuthCredentialStore {
        var hasRefreshToken: Bool { false }
        func clearAll() {}
    }
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() {
        super.setUp()
        suite = "ProfileImport-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }
    private func seed(_ field: String, _ value: String) {
        defaults.set(value, forKey: "ownerProfile.\(DeviceGuestIdentity.ownerKey(in: defaults)).\(field)")
    }
    private func state(_ backend: ImportBackend) -> AuthState {
        AuthState(credentials: Credentials(), defaults: defaults,
                  ownerContext: CurrentOwnerContext(defaults: defaults), profileImportBackend: backend)
    }
    func testNoImplicitDefaultsAndExistingFieldsWin() {
        let user = AppUser(id: "A", provider: .apple, preferredSport: "other")
        XCTAssertNil(InitialProfileImport.proposal(for: user, defaults: defaults))
        seed("preferredSport", "zhuifen"); seed("gender", "unspecified"); seed("birthDate", "2001-02-29")
        XCTAssertNil(InitialProfileImport.proposal(for: user, defaults: defaults))
        seed("yearsPlaying", "threeToFive")
        XCTAssertEqual(InitialProfileImport.proposal(for: user, defaults: defaults)?.fields, ["yearsPlaying": "threeToFive"])
    }
    private func waitForImport(_ auth: AuthState) async {
        for _ in 0..<200 {
            if auth.initialProfileImport == nil || auth.initialProfileImportError != nil { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Automatic profile import did not settle")
    }
    func testLoginAutomaticallyImportsOncePerAccount() async {
        seed("preferredSport", "zhuifen")
        let backend = ImportBackend(), auth = state(backend)
        auth.login(user: AppUser(id: "A", provider: .apple))
        await waitForImport(auth)
        XCTAssertEqual(auth.currentUser?.preferredSport, "zhuifen")
        XCTAssertNil(auth.initialProfileImport)
        XCTAssertTrue(auth.showCloudSyncPrompt, "Training sync remains an independent choice")
        let calls = await backend.calls
        XCTAssertEqual(calls, 1)
        auth.login(user: AppUser(id: "A", provider: .apple))
        XCTAssertNil(auth.initialProfileImport)
        auth.login(user: AppUser(id: "B", provider: .apple))
        await waitForImport(auth)
        XCTAssertEqual(auth.currentUser?.id, "B")
        XCTAssertEqual(auth.currentUser?.preferredSport, "zhuifen")
        let total = await backend.calls
        XCTAssertEqual(total, 2)
    }
    func testFailureRetryPersistsAccountAndRetainsGuest() async {
        seed("preferredSport", "other"); seed("birthDate", "2000-02-29")
        let backend = ImportBackend(), auth = state(backend)
        await backend.configure(fail: true)
        auth.login(user: AppUser(id: "A", provider: .apple))
        await waitForImport(auth)
        XCTAssertNotNil(auth.initialProfileImportError)
        XCTAssertNotNil(auth.initialProfileImport)
        XCTAssertTrue(auth.showCloudSyncPrompt)
        auth.retryPendingInitialProfileImport()
        await waitForImport(auth)
        XCTAssertNil(auth.initialProfileImport)
        XCTAssertEqual(auth.currentUser?.preferredSport, "other")
        let saved = OwnerProfileStore(ownerKey: OwnerKey.account("A"), defaults: defaults)
        XCTAssertEqual(saved.birthDate, "2000-02-29")
        XCTAssertEqual(saved.preferredSport, .other)
        XCTAssertNotNil(InitialProfileImport.proposal(for: AppUser(id: "B", provider: .apple), defaults: defaults))
        auth.login(user: AppUser(id: "A", provider: .apple))
        XCTAssertNil(auth.initialProfileImport)
    }
    func testLateResponseCannotChangeNewAccountOrCompleteItsImport() async {
        seed("preferredSport", "zhuifen")
        let backend = ImportBackend(), auth = state(backend)
        await backend.configure(delay: 100_000_000)
        auth.login(user: AppUser(id: "A", provider: .apple))
        while await backend.calls == 0 { await Task.yield() }
        auth.login(user: AppUser(id: "B", provider: .apple))
        await waitForImport(auth)
        XCTAssertEqual(auth.currentUser?.id, "B")
        XCTAssertEqual(auth.currentUser?.preferredSport, "zhuifen")
        XCTAssertNotNil(InitialProfileImport.proposal(for: AppUser(id: "A", provider: .apple), defaults: defaults))
        XCTAssertNil(InitialProfileImport.proposal(for: AppUser(id: "B", provider: .apple), defaults: defaults))
        auth.invalidateSession()
        XCTAssertNil(auth.initialProfileImport)
    }
    func testAutomaticImportPreservesAnEditMadeDuringTheRequest() async {
        seed("preferredSport", "zhuifen"); seed("birthDate", "2000-01-01")
        let backend = ImportBackend(), auth = state(backend)
        await backend.configure(delay: 100_000_000)
        auth.login(user: AppUser(id: "A", provider: .apple))
        while await backend.calls == 0 { await Task.yield() }
        auth.replaceAuthenticatedUser(AppUser(id: "A", provider: .apple, displayName: "新昵称", preferredSport: "other"))
        await waitForImport(auth)
        XCTAssertEqual(auth.currentUser?.preferredSport, "other")
        XCTAssertEqual(auth.currentUser?.displayName, "新昵称")
        XCTAssertEqual(auth.currentUser?.birthDate, "2000-01-01")
    }
    func testRequestDoesNotTransmitGuestIdentity() throws {
        let proposal = InitialProfileImport(accountID: "A", guestOwner: "private-device", fields: ["gender": "male"])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(proposal)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["accountID", "fields"])
    }
}
