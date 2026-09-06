import Foundation
import SwiftData

// MARK: - Pure curriculum rules

enum OfficialLessonRoleRules {
    /// Classifies a selection without depending on SwiftData or UI state.
    /// Ordinals are zero-based and invalid ordinals are ignored.
    static func classify(
        currentOrdinal: Int?,
        selectedOrdinals: Set<Int>,
        lessonCount: Int
    ) -> [Int: String] {
        let selected = Set(selectedOrdinals.filter { (0..<lessonCount).contains($0) })
        guard let currentOrdinal, (0..<lessonCount).contains(currentOrdinal) else {
            return Dictionary(uniqueKeysWithValues: selected.map { ($0, TodayScheduleProgressRole.review) })
        }

        var firstGap = currentOrdinal
        while selected.contains(firstGap) { firstGap += 1 }

        return Dictionary(uniqueKeysWithValues: selected.map { ordinal in
            if ordinal < currentOrdinal { return (ordinal, TodayScheduleProgressRole.review) }
            if ordinal < firstGap { return (ordinal, TodayScheduleProgressRole.advanceEligible) }
            return (ordinal, TodayScheduleProgressRole.preview)
        })
    }
}

struct ProgressSettlementInput: Equatable {
    let ordinal: Int
    let role: String
    let isCompleted: Bool
}

struct ProgressSettlementResult: Equatable {
    let currentOrdinal: Int?
    let isCompleted: Bool
    let advancedCount: Int
}

enum OfficialPlanProgressRules {
    /// Recomputes the completed eligible contiguous prefix. Replaying the same inputs is idempotent.
    static func settle(
        planID: String,
        activePlanID: String?,
        currentOrdinal: Int?,
        lessonCount: Int,
        items: [ProgressSettlementInput]
    ) -> ProgressSettlementResult {
        guard activePlanID == planID,
              let currentOrdinal,
              (0..<lessonCount).contains(currentOrdinal) else {
            return ProgressSettlementResult(
                currentOrdinal: currentOrdinal,
                isCompleted: currentOrdinal == nil,
                advancedCount: 0
            )
        }

        let completedEligible = Set(items.compactMap { item in
            item.role == TodayScheduleProgressRole.advanceEligible && item.isCompleted
                ? item.ordinal : nil
        })
        var cursor = currentOrdinal
        while cursor < lessonCount, completedEligible.contains(cursor) { cursor += 1 }
        if cursor == lessonCount {
            return ProgressSettlementResult(currentOrdinal: nil, isCompleted: true,
                                            advancedCount: cursor - currentOrdinal)
        }
        return ProgressSettlementResult(currentOrdinal: cursor, isCompleted: false,
                                        advancedCount: cursor - currentOrdinal)
    }
}

enum PlanDurationEstimate {
    static func remainingWeeks(
        lessonCount: Int,
        currentOrdinal: Int?,
        weeklyGoalDays: Int
    ) -> Int {
        guard let currentOrdinal else { return 0 }
        let remaining = max(lessonCount - max(currentOrdinal, 0), 0)
        let pace = max(weeklyGoalDays, 1)
        return remaining == 0 ? 0 : (remaining + pace - 1) / pace
    }
}

// MARK: - Frozen payloads

struct ScheduledLessonPayload: Codable {
    let version: Int
    let planID: String
    let planTitle: String
    let stageID: String
    let stageTitle: String
    let lesson: PlanLesson
    /// Fully resolved at arrangement time. Existing schedules never re-resolve against OTA content.
    let drills: [ScheduledDrillSnapshot]?
}

struct ScheduledSetSnapshot: Codable, Equatable {
    let formationToken: String?
    let formationName: String?
    let targetBalls: Int
    let mode: String?

    init(_ set: PlannedTrainingSet) {
        formationToken = set.formationToken
        formationName = set.formationName
        targetBalls = set.targetBalls
        mode = set.mode?.rawValue
    }

    var plannedSet: PlannedTrainingSet {
        PlannedTrainingSet(
            formationToken: formationToken,
            formationName: formationName,
            targetBalls: targetBalls,
            mode: mode.flatMap(DrillContent.DoseMode.init(rawValue:))
        )
    }
}

struct ScheduledDrillSnapshot: Codable {
    let drillID: String
    let name: String
    let description: String
    let coachingPoints: [String]
    let sets: [ScheduledSetSnapshot]
    let phaseType: String
    let phaseTitle: String
    let animation: DrillAnimation?
    let level: String?
    let category: String
    let subcategory: String
    let standardCriteria: String
}

struct ScheduledTemplateDrillPayload: Codable {
    let drillID: String
    let drillName: String
    let roundsPerFormation: Int
    let order: Int
}

struct ScheduledTemplatePayload: Codable {
    let version: Int
    let templateID: String
    let title: String
    let drills: [ScheduledTemplateDrillPayload]
    let resolvedDrills: [ScheduledDrillSnapshot]?
}

struct ScheduledLibraryDrillPayload: Codable {
    let version: Int
    let drillID: String
    let title: String
    let roundsPerFormation: Int
    let resolvedDrill: ScheduledDrillSnapshot?
}

// MARK: - Persisted schedule service

@MainActor
final class TodayTrainingScheduleService {
    enum Error: Swift.Error, Equatable {
        case activePlanMismatch
        case lessonNotFound
        case invalidReorder
        case itemNotEditable
        case sourceUnavailable
    }

    enum AddResult {
        case added(TodayScheduleItem)
        case alreadyPresent(TodayScheduleItem)
    }

    private let context: ModelContext
    private let now: () -> Date
    private let timeZone: TimeZone
    private let calendarIdentifier: String

    init(
        context: ModelContext,
        now: @escaping () -> Date = Date.init,
        timeZone: TimeZone = .current,
        calendarIdentifier: String = "gregorian"
    ) {
        self.context = context
        self.now = now
        self.timeZone = timeZone
        self.calendarIdentifier = calendarIdentifier
    }

    func today(ownerKey: String, createIfNeeded: Bool = true) throws -> TodayTrainingSchedule? {
        let date = now()
        let key = Self.localDayKey(for: date, timeZone: timeZone)
        let all = try schedules(ownerKey: ownerKey)
        for schedule in all where schedule.archivedAt == nil && schedule.localDayKey < key {
            schedule.archivedAt = date
            schedule.updatedAt = date
        }
        if let current = Self.currentSchedule(in: all, ownerKey: ownerKey, dayKey: key) {
            if context.hasChanges { try context.save() }
            return current
        }
        guard createIfNeeded else {
            if context.hasChanges { try context.save() }
            return nil
        }
        let schedule = TodayTrainingSchedule(
            ownerKey: ownerKey,
            localDayKey: key,
            calendarIdentifier: calendarIdentifier,
            timeZoneIdentifier: timeZone.identifier,
            createdAt: date
        )
        context.insert(schedule)
        try context.save()
        return schedule
    }

    @discardableResult
    func addOfficialLessons(
        plan: OfficialPlan,
        lessonIDs: Set<String>,
        activePlan: UserActivePlan
    ) throws -> [AddResult] {
        guard !activePlan.isCustom, activePlan.planId == plan.id else {
            throw Error.activePlanMismatch
        }
        let ownerKey = activePlan.ownerKey
        let schedule = try requiredToday(ownerKey: ownerKey)
        let flattened = Self.flatten(plan)
        let ordinalByID = Dictionary(uniqueKeysWithValues: flattened.enumerated().map { ($0.element.lesson.id, $0.offset) })
        let requested = try lessonIDs.map { id -> Int in
            guard let ordinal = ordinalByID[id] else { throw Error.lessonNotFound }
            return ordinal
        }
        let currentOrdinal = activePlan.currentLessonId.flatMap { ordinalByID[$0] }

        let existingEligible = schedule.items.compactMap { item -> Int? in
            guard item.planId == plan.id,
                  item.state != TodayScheduleItemState.completed,
                  item.state != TodayScheduleItemState.abandoned,
                  item.progressRole == TodayScheduleProgressRole.advanceEligible,
                  let lessonID = item.lessonId else { return nil }
            return ordinalByID[lessonID]
        }
        let classificationSelection = Set(requested).union(existingEligible)
        let roles = OfficialLessonRoleRules.classify(
            currentOrdinal: currentOrdinal,
            selectedOrdinals: classificationSelection,
            lessonCount: flattened.count
        )

        var results: [AddResult] = []
        for ordinal in requested.sorted() {
            let value = flattened[ordinal]
            if let existing = unfinishedItem(
                in: schedule, sourceKind: TodayScheduleSourceKind.officialLesson,
                sourceID: value.lesson.id
            ) {
                results.append(.alreadyPresent(existing))
                continue
            }
            let payload = try JSONEncoder().encode(ScheduledLessonPayload(
                version: 1, planID: plan.id, planTitle: plan.nameZh,
                stageID: value.stage.id, stageTitle: value.stage.title,
                lesson: value.lesson,
                drills: Self.snapshots(for: value.lesson)
            ))
            let item = TodayScheduleItem(
                orderIndex: nextOrder(in: schedule),
                sourceKind: TodayScheduleSourceKind.officialLesson,
                sourceId: value.lesson.id,
                sourceParentId: plan.id,
                sourceTitleSnapshot: value.lesson.title,
                sourceSubtitleSnapshot: "\(value.stage.title) · 第 \(value.lesson.order) 课",
                payloadSnapshot: payload,
                progressRole: roles[ordinal] ?? TodayScheduleProgressRole.preview,
                planId: plan.id,
                lessonId: value.lesson.id,
                createdAt: now()
            )
            attach(item, to: schedule)
            results.append(.added(item))
        }
        try context.save()
        return results
    }

    @discardableResult
    func addTemplate(_ template: CustomPlan) throws -> AddResult {
        let schedule = try requiredToday(ownerKey: template.ownerKey)
        let sourceID = template.id.uuidString
        if let existing = unfinishedItem(in: schedule, sourceKind: TodayScheduleSourceKind.template,
                                         sourceID: sourceID) {
            return .alreadyPresent(existing)
        }
        let drills = template.drills.sorted { $0.order < $1.order }.map {
            ScheduledTemplateDrillPayload(drillID: $0.drillId, drillName: $0.drillNameZh,
                                          roundsPerFormation: $0.roundsPerFormation, order: $0.order)
        }
        let payload = try JSONEncoder().encode(ScheduledTemplatePayload(
            version: 1, templateID: sourceID, title: template.name, drills: drills,
            resolvedDrills: drills.map {
                Self.snapshot(
                    drillID: $0.drillID,
                    fallbackName: $0.drillName,
                    dose: PlanDrillDose(roundsPerFormation: $0.roundsPerFormation),
                    phaseType: "focused",
                    phaseTitle: "专项训练"
                )
            }
        ))
        let item = TodayScheduleItem(
            orderIndex: nextOrder(in: schedule), sourceKind: TodayScheduleSourceKind.template,
            sourceId: sourceID, sourceTitleSnapshot: template.name,
            sourceSubtitleSnapshot: "\(drills.count) 个动作", payloadSnapshot: payload,
            progressRole: TodayScheduleProgressRole.neutral, createdAt: now()
        )
        attach(item, to: schedule)
        try context.save()
        return .added(item)
    }

    @discardableResult
    func addLibraryDrill(id: String, title: String, ownerKey: String,
                         roundsPerFormation: Int = 1) throws -> AddResult {
        let schedule = try requiredToday(ownerKey: ownerKey)
        if let existing = unfinishedItem(in: schedule,
                                         sourceKind: TodayScheduleSourceKind.libraryDrill,
                                         sourceID: id) {
            return .alreadyPresent(existing)
        }
        let payload = try JSONEncoder().encode(ScheduledLibraryDrillPayload(
            version: 1, drillID: id, title: title,
            roundsPerFormation: max(roundsPerFormation, 1),
            resolvedDrill: Self.snapshot(
                drillID: id,
                fallbackName: title,
                dose: PlanDrillDose(roundsPerFormation: max(roundsPerFormation, 1)),
                phaseType: "focused",
                phaseTitle: "动作库"
            )
        ))
        let item = TodayScheduleItem(
            orderIndex: nextOrder(in: schedule), sourceKind: TodayScheduleSourceKind.libraryDrill,
            sourceId: id, sourceTitleSnapshot: title, payloadSnapshot: payload,
            progressRole: TodayScheduleProgressRole.neutral, createdAt: now()
        )
        attach(item, to: schedule)
        try context.save()
        return .added(item)
    }

    func reorderUnfinished(_ orderedIDs: [UUID], in schedule: TodayTrainingSchedule) throws {
        let sorted = schedule.items.sorted { $0.orderIndex < $1.orderIndex }
        let unfinished = sorted.filter {
            $0.state != TodayScheduleItemState.completed && $0.state != TodayScheduleItemState.abandoned
        }
        guard orderedIDs.count == unfinished.count, Set(orderedIDs) == Set(unfinished.map(\.id)) else {
            throw Error.invalidReorder
        }
        let byID = Dictionary(uniqueKeysWithValues: unfinished.map { ($0.id, $0) })
        var iterator = orderedIDs.compactMap { byID[$0] }.makeIterator()
        let reordered = sorted.map { item in
            unfinished.contains(where: { $0.id == item.id }) ? (iterator.next() ?? item) : item
        }
        for (index, item) in reordered.enumerated() { item.orderIndex = index }
        schedule.updatedAt = now()
        try context.save()
    }

    func removePending(_ item: TodayScheduleItem) throws {
        guard item.state == TodayScheduleItemState.pending else { throw Error.itemNotEditable }
        item.schedule?.updatedAt = now()
        context.delete(item)
        try context.save()
    }

    func markStarted(_ item: TodayScheduleItem) throws {
        guard item.state == TodayScheduleItemState.pending else { throw Error.itemNotEditable }
        item.state = TodayScheduleItemState.inProgress
        item.startedAt = now()
        item.schedule?.updatedAt = now()
        try context.save()
    }

    func abandon(_ item: TodayScheduleItem) throws {
        guard item.state == TodayScheduleItemState.pending || item.state == TodayScheduleItemState.inProgress
        else { throw Error.itemNotEditable }
        item.state = TodayScheduleItemState.abandoned
        item.schedule?.updatedAt = now()
        try context.save()
    }

    func latestArchivedWithUnfinished(ownerKey: String) throws -> TodayTrainingSchedule? {
        try schedules(ownerKey: ownerKey)
            .filter { $0.archivedAt != nil && $0.items.contains(where: Self.isUnfinished) }
            .max { $0.localDayKey < $1.localDayKey }
    }

    /// Carry-over is not an explicit repeat: today's saved/completed sources count too.
    static func carryForwardCandidates(
        from previous: TodayTrainingSchedule, todayItems: [TodayScheduleItem], activePlanID: String?
    ) -> [TodayScheduleItem] {
        previous.items.filter { source in
            guard isUnfinished(source) else { return false }
            if source.sourceKind == TodayScheduleSourceKind.officialLesson {
                return source.planId == activePlanID
                    && !todayItems.contains { $0.planId == source.planId }
            }
            return !todayItems.contains {
                $0.sourceKind == source.sourceKind && $0.sourceId == source.sourceId
            }
        }.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Copies the last archived day's unfinished snapshots. Official lessons are classified again
    /// against today's cursor; the archived facts remain unchanged.
    @discardableResult
    func carryForwardLatestUnfinished(
        ownerKey: String,
        activePlan: UserActivePlan?,
        officialPlan: OfficialPlan?
    ) throws -> [AddResult] {
        guard let previous = try latestArchivedWithUnfinished(ownerKey: ownerKey) else { return [] }
        let today = try requiredToday(ownerKey: ownerKey)
        let sourceItems = Self.carryForwardCandidates(
            from: previous, todayItems: today.items, activePlanID: activePlan?.planId)
        var results: [AddResult] = []

        if let activePlan, let officialPlan, activePlan.planId == officialPlan.id {
            let ids = Set(sourceItems.compactMap { item in
                item.planId == officialPlan.id ? item.lessonId : nil
            })
            results += try addOfficialLessons(plan: officialPlan, lessonIDs: ids, activePlan: activePlan)
        }

        let schedule = try requiredToday(ownerKey: ownerKey)
        for source in sourceItems where source.sourceKind != TodayScheduleSourceKind.officialLesson {
            if let existing = unfinishedItem(in: schedule, sourceKind: source.sourceKind,
                                             sourceID: source.sourceId) {
                results.append(.alreadyPresent(existing))
                continue
            }
            let copy = TodayScheduleItem(
                orderIndex: nextOrder(in: schedule), sourceKind: source.sourceKind,
                sourceId: source.sourceId, sourceParentId: source.sourceParentId,
                sourceTitleSnapshot: source.sourceTitleSnapshot,
                sourceSubtitleSnapshot: source.sourceSubtitleSnapshot,
                payloadVersion: source.payloadVersion, payloadSnapshot: source.payloadSnapshot,
                progressRole: TodayScheduleProgressRole.neutral,
                planId: nil, lessonId: nil, createdAt: now()
            )
            attach(copy, to: schedule)
            results.append(.added(copy))
        }
        try context.save()
        return results
    }

    static func localDayKey(for date: Date, timeZone: TimeZone) -> String {
        V54DataMigration.localDayKey(for: date, timeZone: timeZone)
    }

    static func currentSchedule(in schedules: [TodayTrainingSchedule], ownerKey: String,
                                dayKey: String) -> TodayTrainingSchedule? {
        schedules.filter {
            $0.ownerKey == ownerKey && $0.localDayKey == dayKey && $0.archivedAt == nil
        }.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString > $1.id.uuidString
        }.first
    }

    private func requiredToday(ownerKey: String) throws -> TodayTrainingSchedule {
        guard let schedule = try today(ownerKey: ownerKey) else { throw Error.sourceUnavailable }
        return schedule
    }

    private func schedules(ownerKey: String) throws -> [TodayTrainingSchedule] {
        try context.fetch(FetchDescriptor(predicate: #Predicate<TodayTrainingSchedule> {
            $0.ownerKey == ownerKey
        }))
    }

    private func unfinishedItem(in schedule: TodayTrainingSchedule,
                                sourceKind: String, sourceID: String) -> TodayScheduleItem? {
        schedule.items.first {
            $0.sourceKind == sourceKind && $0.sourceId == sourceID && Self.isUnfinished($0)
        }
    }

    private func attach(_ item: TodayScheduleItem, to schedule: TodayTrainingSchedule) {
        item.schedule = schedule
        schedule.items.append(item)
        schedule.updatedAt = now()
        context.insert(item)
    }

    private func nextOrder(in schedule: TodayTrainingSchedule) -> Int {
        (schedule.items.map(\.orderIndex).max() ?? -1) + 1
    }

    private static func isUnfinished(_ item: TodayScheduleItem) -> Bool {
        item.state == TodayScheduleItemState.pending || item.state == TodayScheduleItemState.inProgress
    }

    private static func flatten(_ plan: OfficialPlan) -> [(stage: PlanStage, lesson: PlanLesson)] {
        plan.stages.sorted { $0.order < $1.order }.flatMap { stage in
            stage.lessons.sorted { $0.order < $1.order }.map { (stage, $0) }
        }
    }

    private static func snapshots(for lesson: PlanLesson) -> [ScheduledDrillSnapshot] {
        lesson.phases.flatMap { phase in
            phase.drills.map {
                snapshot(
                    drillID: $0.drillId,
                    fallbackName: $0.drillId,
                    dose: $0.dose,
                    phaseType: phase.type,
                    phaseTitle: phase.typeZh
                )
            }
        }
    }

    private static func snapshot(
        drillID: String,
        fallbackName: String,
        dose: PlanDrillDose?,
        phaseType: String,
        phaseTitle: String
    ) -> ScheduledDrillSnapshot {
        let content = DrillContentService.decodeDrillFromBundle(id: drillID)
        let resolved = TrainingDoseResolver.resolve(
            content: content,
            dose: dose,
            formationOptions: TrainingDoseResolver.formationOptions(forDrillId: drillID)
        )
        return ScheduledDrillSnapshot(
            drillID: drillID,
            name: content?.nameZh ?? fallbackName,
            description: content?.description ?? "",
            coachingPoints: content?.coachingPoints ?? [],
            sets: resolved.plannedSets.map(ScheduledSetSnapshot.init),
            phaseType: phaseType,
            phaseTitle: phaseTitle,
            animation: content?.animation,
            level: content?.level,
            category: content?.category ?? "",
            subcategory: content?.subcategory ?? "",
            standardCriteria: content?.standardCriteria ?? ""
        )
    }
}
