import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class AngleTestViewModelTests: XCTestCase {

    var limiter: AngleUsageLimiter!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "AngleUsage_count")
        UserDefaults.standard.removeObject(forKey: "AngleUsage_date")
        UserDefaults.standard.removeObject(forKey: "AdaptiveQuestionEngine_v1")
        limiter = AngleUsageLimiter()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "AngleUsage_count")
        UserDefaults.standard.removeObject(forKey: "AngleUsage_date")
        UserDefaults.standard.removeObject(forKey: "AdaptiveQuestionEngine_v1")
        limiter = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initial_state() {
        let vm = AngleTestViewModel(limiter: limiter)
        XCTAssertNil(vm.currentQuestion)
        XCTAssertTrue(vm.userInput.isEmpty)
        XCTAssertEqual(vm.questionIndex, 0)
        XCTAssertFalse(vm.showResult)
        XCTAssertFalse(vm.testFinished)
        XCTAssertTrue(vm.sessionResults.isEmpty)
        XCTAssertEqual(vm.totalQuestions, 20)
    }

    // MARK: - startTest

    func test_startTest_generates_first_question() {
        let vm = AngleTestViewModel(limiter: limiter)
        vm.startTest()
        XCTAssertNotNil(vm.currentQuestion)
        XCTAssertEqual(vm.questionIndex, 0)
        XCTAssertFalse(vm.testFinished)
    }

    // MARK: - submitAnswer

    func test_submitAnswer_valid_input() {
        let vm = AngleTestViewModel(limiter: limiter)
        vm.startTest()
        guard let q = vm.currentQuestion else {
            XCTFail("Question should exist")
            return
        }
        vm.userInput = String(Int(q.actualAngle))
        vm.submitAnswer()

        XCTAssertTrue(vm.showResult)
        XCTAssertEqual(vm.sessionResults.count, 1)
        XCTAssertEqual(vm.sessionResults.first?.error ?? -1, 0, accuracy: 0.001)
    }

    func test_submitAnswer_invalid_input_ignored() {
        let vm = AngleTestViewModel(limiter: limiter)
        vm.startTest()
        vm.userInput = "abc"
        vm.submitAnswer()
        XCTAssertFalse(vm.showResult)
        XCTAssertTrue(vm.sessionResults.isEmpty)
    }

    func test_submitAnswer_negative_ignored() {
        let vm = AngleTestViewModel(limiter: limiter)
        vm.startTest()
        vm.userInput = "-5"
        vm.submitAnswer()
        XCTAssertTrue(vm.sessionResults.isEmpty)
    }

    func test_submitAnswer_over_90_ignored() {
        let vm = AngleTestViewModel(limiter: limiter)
        vm.startTest()
        vm.userInput = "95"
        vm.submitAnswer()
        XCTAssertTrue(vm.sessionResults.isEmpty)
    }

    // MARK: - advanceToNext

    func test_advanceToNext_increments_index() {
        let vm = AngleTestViewModel(limiter: limiter)
        vm.startTest()
        vm.userInput = "45"
        vm.submitAnswer()
        vm.advanceToNext()
        XCTAssertEqual(vm.questionIndex, 1)
        XCTAssertFalse(vm.showResult)
    }

    // MARK: - Finish test

    func test_test_finishes_after_20_questions() {
        let vm = AngleTestViewModel(limiter: limiter)
        limiter.isPremium = true
        vm.startTest()

        for i in 0..<20 {
            guard vm.currentQuestion != nil else {
                XCTFail("Question \(i) should exist")
                return
            }
            vm.userInput = "45"
            vm.submitAnswer()
            if i < 19 {
                vm.advanceToNext()
            }
        }

        vm.advanceToNext()
        XCTAssertTrue(vm.testFinished)
        XCTAssertEqual(vm.sessionResults.count, 20)
    }

    // MARK: - Limiter integration

    func test_limiter_stops_test_when_reached() {
        for _ in 0..<20 { limiter.recordQuestion() }
        XCTAssertTrue(limiter.isLimitReached)

        let vm = AngleTestViewModel(limiter: limiter)
        vm.startTest()
        XCTAssertTrue(vm.testFinished)
    }

    // MARK: - Derived stats

    func test_averageError() {
        let vm = AngleTestViewModel(limiter: limiter)
        vm.startTest()

        for _ in 0..<3 {
            guard let q = vm.currentQuestion else { break }
            let answer = Int(q.actualAngle) + 5
            vm.userInput = "\(min(answer, 90))"
            vm.submitAnswer()
            vm.advanceToNext()
        }
        XCTAssertGreaterThan(vm.averageError, 0)
    }

    func test_accurateCount() {
        let vm = AngleTestViewModel(limiter: limiter)
        vm.startTest()

        guard let q = vm.currentQuestion else {
            XCTFail("Question should exist")
            return
        }
        vm.userInput = String(Int(q.actualAngle))
        vm.submitAnswer()

        XCTAssertEqual(vm.accurateCount, 1)
    }

    // MARK: - ErrorRating

    func test_errorRating_accurate() {
        let vm = AngleTestViewModel(limiter: limiter)
        vm.startTest()
        guard let q = vm.currentQuestion else { return }
        vm.userInput = String(Int(q.actualAngle))
        vm.submitAnswer()
        XCTAssertEqual(vm.errorRating, .accurate)
    }

    func test_errorRating_no_results() {
        let vm = AngleTestViewModel(limiter: limiter)
        XCTAssertEqual(vm.errorRating, .accurate)
    }
}
