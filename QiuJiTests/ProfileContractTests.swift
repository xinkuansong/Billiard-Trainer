import XCTest
@testable import QiuJi

final class ProfileContractTests: XCTestCase {

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
