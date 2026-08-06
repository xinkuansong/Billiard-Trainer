//
//  AngleResultSaveFailureTests.swift
//  QiuJiTests
//
//  问题集合 v29 W1：「练」分区 4 个答题入口的成绩落库失败路径。
//  改造前 4 处都是 `try? await repository?.save(result)`——保存失败静默丢题，
//  用户既看不到错误也拿不回答案。本组测试注入必然失败的仓储，断言：
//    1. 可见错误态 `saveErrorMessage` 被置起；
//    2. 用户答案仍在（`sessionResults` 保留本题）；
//    3. 失败成绩进入 `unsavedResults`，可重试而非丢弃。
//

import XCTest
import SwiftData
@testable import QiuJi

private struct AngleSaveFailureStub: AngleTestRepositoryProtocol {

    struct InjectedFailure: LocalizedError {
        var errorDescription: String? { "注入的落库失败" }
    }

    func save(_ result: AngleTestResult) async throws { throw InjectedFailure() }
    func fetchAll() async throws -> [AngleTestResult] { throw InjectedFailure() }
    func fetchInRange(from: Date, to: Date) async throws -> [AngleTestResult] {
        throw InjectedFailure()
    }
    func deleteAll() async throws { throw InjectedFailure() }
}

@MainActor
final class AngleResultSaveFailureTests: XCTestCase {

    /// 独立 defaults + isPremium，避免测试消耗真实每日额度、也不受额度上限影响。
    private func makeLimiter() -> AngleUsageLimiter {
        let suite = UserDefaults(suiteName: "AngleResultSaveFailureTests-\(UUID().uuidString)")!
        let limiter = AngleUsageLimiter(defaults: suite)
        limiter.isPremium = true
        return limiter
    }

    /// 轮询等待异步保存 Task 落到错误态（最多 5 秒）。
    private func waitForErrorState(_ read: @MainActor () -> String?) async throws -> String {
        for _ in 0..<250 {
            if let message = read() { return message }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("等待保存失败错误态超时")
        return ""
    }

    // MARK: - 1. 角度预测（GeometricAngleViewModel）

    func test_geometricAngle_saveFailure_setsErrorAndKeepsAnswer() async throws {
        let vm = GeometricAngleViewModel(limiter: makeLimiter())
        vm.configure(repository: AngleSaveFailureStub())
        vm.currentAngle = 42
        vm.userInput = "35"

        vm.submitAnswer()

        let message = try await waitForErrorState { vm.saveErrorMessage }
        XCTAssertTrue(message.contains("注入的落库失败"), "错误文案应带上失败原因：\(message)")
        XCTAssertEqual(vm.unsavedResults.count, 1, "失败成绩必须保留待重试，不得丢弃")
        XCTAssertEqual(vm.sessionResults.count, 1, "用户答案必须保留在本次会话统计里")
        XCTAssertEqual(vm.sessionResults.last?.userAngle, 35)
        XCTAssertEqual(vm.userInput, "35", "输入框内容不得被清空")
        XCTAssertTrue(vm.showResult, "结果面仍应展示")
    }

    // MARK: - 2. 2D/3D 角度训练（AimingQuizViewModel）

    func test_aimingQuiz_saveFailure_setsErrorAndKeepsAnswer() async throws {
        let vm = AimingQuizViewModel(limiter: makeLimiter())
        vm.configure(repository: AngleSaveFailureStub())
        let question = AngleCalculator.generateQuestion(angle: 30)
        vm.currentQuestion = question
        vm.userInput = "20"

        vm.submitAnswer()

        let message = try await waitForErrorState { vm.saveErrorMessage }
        XCTAssertTrue(message.contains("注入的落库失败"), "错误文案应带上失败原因：\(message)")
        XCTAssertEqual(vm.unsavedResults.count, 1, "失败成绩必须保留待重试，不得丢弃")
        XCTAssertEqual(vm.sessionResults.count, 1, "用户答案必须保留在本次会话统计里")
        XCTAssertEqual(vm.sessionResults.last?.userAngle, 20)
        XCTAssertEqual(try XCTUnwrap(vm.sessionResults.last).error,
                       abs(question.actualAngle - 20),
                       accuracy: 1e-9)
    }

    // MARK: - 3. 瞄准点训练（AimPointTrainingViewModel）

    func test_aimPointTraining_saveFailure_setsErrorAndKeepsAnswer() async throws {
        let vm = AimPointTrainingViewModel(limiter: makeLimiter())
        vm.configure(repository: AngleSaveFailureStub())
        vm.setQuestionForTesting(.init(angleDegrees: 30, cutsRight: true))
        vm.userPhi = -0.3

        let expectedOffset = vm.userOffsetMM
        vm.submit()

        let message = try await waitForErrorState { vm.saveErrorMessage }
        XCTAssertTrue(message.contains("注入的落库失败"), "错误文案应带上失败原因：\(message)")
        XCTAssertEqual(vm.unsavedResults.count, 1, "失败成绩必须保留待重试，不得丢弃")
        XCTAssertEqual(vm.sessionResults.count, 1, "用户答案必须保留在本次会话统计里")
        XCTAssertEqual(vm.userPhi, -0.3, accuracy: 1e-9, "用户瞄准输入不得被重置")
        XCTAssertEqual(vm.userOffsetMM, expectedOffset, accuracy: 1e-9)
    }

    // MARK: - 4. 2D/3D 瞄准点训练（AimPointSceneQuizViewModel）

    func test_aimPointSceneQuiz_saveFailure_setsErrorAndKeepsAnswer() async throws {
        let vm = AimPointSceneQuizViewModel(limiter: makeLimiter())
        vm.configure(repository: AngleSaveFailureStub())
        vm.setupScene(cameraMode: .topDown2D)
        XCTAssertNotNil(vm.question, "前置：场景应已出题")

        vm.submit()

        let message = try await waitForErrorState { vm.saveErrorMessage }
        XCTAssertTrue(message.contains("注入的落库失败"), "错误文案应带上失败原因：\(message)")
        XCTAssertEqual(vm.unsavedResults.count, 1, "失败成绩必须保留待重试，不得丢弃")
        XCTAssertEqual(vm.sessionResults.count, 1, "用户答案必须保留在本次会话统计里")
        XCTAssertNotNil(vm.lastErrorMM, "本题误差读数必须仍在")
    }

    // MARK: - 重试

    func test_retryFailedSaves_clearsErrorWhenRepositoryRecovers() async throws {
        let vm = GeometricAngleViewModel(limiter: makeLimiter())
        vm.configure(repository: AngleSaveFailureStub())
        vm.currentAngle = 42
        vm.userInput = "35"
        vm.submitAnswer()
        _ = try await waitForErrorState { vm.saveErrorMessage }

        let container = ModelContainerFactory.makeInMemoryContainer()
        vm.configure(repository: LocalAngleTestRepository(context: ModelContext(container)))
        vm.retryFailedSaves()

        for _ in 0..<250 where !vm.unsavedResults.isEmpty || vm.saveErrorMessage != nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertNil(vm.saveErrorMessage, "重试成功后错误态应清除")
        XCTAssertTrue(vm.unsavedResults.isEmpty, "重试成功后不应再有待保存成绩")
        XCTAssertEqual(vm.sessionResults.count, 1)
    }
}
