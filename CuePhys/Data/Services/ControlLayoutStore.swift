import Foundation
import Combine
import CryptoKit

/// v2 owns a separate file. The legacy archive remains untouched for explicit migration.
@MainActor
final class FreeControlLayoutStore: ObservableObject {
    static let shared: FreeControlLayoutStore = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-freeLayout.ephemeral") {
            return FreeControlLayoutStore(storage: EphemeralControlLayoutStorage())
        }
        #endif
        return FreeControlLayoutStore(storage: ControlLayoutFileStorage(
            url: ControlLayoutFileStorage.application.url.deletingLastPathComponent().appendingPathComponent("layouts-v2.json")),
            legacyStorage: ControlLayoutFileStorage.application)
    }()
    @Published private(set) var archive = FreeControlArchive()
    @Published private(set) var loadError: String?
    @Published private(set) var legacyArchive: ControlLayoutArchive?
    @Published private(set) var legacyError: String?
    private let storage: any ControlLayoutStorage
    private let legacyStorage: (any ControlLayoutStorage)?
    private var loadedBytes: Data?
    private var legacyBytes: Data?

    init(storage: any ControlLayoutStorage, legacyStorage: (any ControlLayoutStorage)? = nil) {
        self.storage = storage; self.legacyStorage = legacyStorage; reload(); reloadLegacy()
    }

    func reloadLegacy() {
        do {
            legacyBytes = try legacyStorage?.read()
            legacyArchive = try legacyBytes.map(ControlLayoutStore.decode)
            legacyError = nil
        } catch { legacyError = error.localizedDescription; legacyArchive = nil }
    }

    func backUpLegacy() throws {
        guard let legacyStorage, let bytes = try legacyStorage.read() else { return }
        try legacyStorage.preserve(bytes)
    }

    /// Explicit page-local recovery creates a draft, never rewrites or guesses the source page.
    func recoverLegacyDraft(_ id: UUID, page: TablePreferencePage, mode: FreeControlLayoutMode,
                            domain: ControlLayoutDomain, input: ControlLayoutPlacement.Input,
                            controls: [String: FreeControlLegacyMeasurements.Control],
                            window: FreeControlWindow) throws -> FreeControlLegacyConverter.Conversion {
        guard page.supportsControlLayoutEditing else { throw ControlLayoutError.unsupportedPage }
        reloadLegacy()
        guard var legacy = legacyArchive, legacy.templates[id] != nil else { throw ControlLayoutError.missingTemplate }
        try backUpLegacy()
        legacy.bindings[page] = .init(selection: .template(id))
        return FreeControlLegacyConverter.convert(legacy, page: page, mode: mode, domain: domain,
            input: input, controls: controls, window: window)
    }

    func recoverUnassignedDraft(_ template: FreeControlTemplate, page: TablePreferencePage,
                                mode: FreeControlLayoutMode) throws -> FreeControlValues {
        guard TablePreferencePage(rawValue: template.sourcePage)?.supportsControlLayoutEditing != true else {
            throw ControlLayoutError.unsupportedPage
        }
        guard archive.templates.contains(template) else { throw ControlLayoutError.conflict }
        return try template.merging(into: [:], page: page, mode: mode)
    }

    func reload() {
        do {
            let bytes = try storage.read()
            let candidate = try bytes.map { try Self.decode($0) } ?? FreeControlArchive()
            try candidate.validate()
            loadedBytes = bytes
            archive = candidate
            loadError = nil
        } catch { loadError = error.localizedDescription }
    }

    func values(page: TablePreferencePage, mode: FreeControlLayoutMode) -> FreeControlValues {
        archive.pages[FreeControlArchive.key(page: page, mode: mode)] ?? [:]
    }

    func pageRevision(page: TablePreferencePage, mode: FreeControlLayoutMode) -> UInt64 {
        archive.pageRevision(FreeControlArchive.key(page: page, mode: mode))
    }

    /// One atomic write publishes the new template and page result together.
    func saveNew(id: UUID, name: String, page: TablePreferencePage, mode: FreeControlLayoutMode,
                 values: FreeControlValues, sourceOnly: FreeControlValues = [:], expectedRevision: UInt64 = 0,
                 expectedPageRevision: UInt64? = nil, sourceWindow: FreeControlWindow? = nil,
                 sourceTemplateID: UUID? = nil) throws {
        let trimmed = FreeControlTemplate.userName(name)
        guard !trimmed.isEmpty, page.supportsControlLayoutEditing else { throw ControlLayoutError.invalidConfiguration }
        let combined = sourceOnly.merging(values) { _, new in new }
        let key = FreeControlArchive.key(page: page, mode: mode)
        // A retry of the same submitted intent never generates a second template or reapplies a stale page.
        if expectedPageRevision != nil {
            let (latest, bytes) = try readLatest()
            if let existing = latest.templates.first(where: { $0.id == id }) {
                guard existing.baseName == trimmed, existing.mode == mode, existing.sourcePage == page.rawValue,
                      existing.values == combined, existing.sourceTemplateID == sourceTemplateID,
                      existing.sourceWindow == sourceWindow else { throw ControlLayoutError.duplicateTemplate }
                loadedBytes = bytes; archive = latest
                return
            }
        }
        let change: (inout FreeControlArchive) throws -> Void = { candidate in
            guard !candidate.templates.contains(where: { $0.id == id }) else { throw ControlLayoutError.duplicateTemplate }
            candidate.templates.append(FreeControlTemplate(id: id, baseName: trimmed, mode: mode,
                sourcePage: page.rawValue, values: combined, sourceWindow: sourceWindow, sourceTemplateID: sourceTemplateID))
            candidate.pages[key] = values
            try candidate.changedPage(key, source: id)
        }
        if let expectedPageRevision {
            try transactPage(key: key, expectedRevision: expectedPageRevision, change: change)
        } else {
            try transact(expectedRevision: expectedRevision, change: change)
        }
    }

    func restore(page: TablePreferencePage, mode: FreeControlLayoutMode, expectedRevision: UInt64 = 0,
                 expectedPageRevision: UInt64? = nil) throws {
        let key = FreeControlArchive.key(page: page, mode: mode)
        let change: (inout FreeControlArchive) throws -> Void = { candidate in
            candidate.pages.removeValue(forKey: key)
            try candidate.changedPage(key, source: nil)
        }
        if let expectedPageRevision { try transactPage(key: key, expectedRevision: expectedPageRevision, change: change) }
        else { try transact(expectedRevision: expectedRevision, change: change) }
    }

    func apply(_ templateID: UUID, page: TablePreferencePage, mode: FreeControlLayoutMode,
               expectedPageRevision: UInt64) throws {
        let key = FreeControlArchive.key(page: page, mode: mode)
        try transactPage(key: key, expectedRevision: expectedPageRevision) { candidate in
            guard let template = candidate.templates.first(where: { $0.id == templateID }) else {
                throw ControlLayoutError.missingTemplate
            }
            candidate.pages[key] = try template.merging(into: candidate.pages[key] ?? [:], page: page, mode: mode)
            try candidate.changedPage(key, source: templateID)
        }
    }

    /// User-facing actions are page/mode scoped; legacy intersection application remains migration-only.
    func validateLocal(_ template: FreeControlTemplate, page: TablePreferencePage, mode: FreeControlLayoutMode) throws {
        guard page.supportsControlLayoutEditing, template.sourcePage == page.rawValue else {
            throw ControlLayoutError.unsupportedPage
        }
        guard template.mode == mode else { throw ControlLayoutError.modeMismatch }
    }

    func applyLocal(_ templateID: UUID, page: TablePreferencePage, mode: FreeControlLayoutMode,
                    expectedPageRevision: UInt64) throws {
        let key = FreeControlArchive.key(page: page, mode: mode)
        try transactPage(key: key, expectedRevision: expectedPageRevision) { candidate in
            guard let template = candidate.templates.first(where: { $0.id == templateID }) else {
                throw ControlLayoutError.missingTemplate
            }
            try self.validateLocal(template, page: page, mode: mode)
            candidate.pages[key] = try template.merging(into: candidate.pages[key] ?? [:], page: page, mode: mode)
            try candidate.changedPage(key, source: templateID)
        }
    }

    func setPinnedLocal(_ template: FreeControlTemplate, pinned: Bool,
                        page: TablePreferencePage, mode: FreeControlLayoutMode) throws {
        try validateLocal(template, page: page, mode: mode)
        try setPinned(template, pinned: pinned)
    }

    func deleteLocal(_ template: FreeControlTemplate, page: TablePreferencePage, mode: FreeControlLayoutMode) throws {
        try validateLocal(template, page: page, mode: mode)
        try delete(template)
    }

    /// Modes and pages never share a template list.
    func localTemplates(page: TablePreferencePage, mode: FreeControlLayoutMode) -> [FreeControlTemplate] {
        archive.templates.filter { $0.sourcePage == page.rawValue && $0.mode == mode }.sorted {
            if $0.pinnedAt != $1.pinnedAt { return ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func setPinned(_ template: FreeControlTemplate, pinned: Bool) throws {
        var (candidate, _) = try readLatest()
        guard let index = candidate.templates.firstIndex(where: { $0.id == template.id }) else { throw ControlLayoutError.missingTemplate }
        guard candidate.templates[index] == template else { throw ControlLayoutError.conflict }
        candidate.templates[index].pinnedAt = pinned ? Date() : nil
        try publish(candidate)
    }

    /// Updating a local template keeps its identity and only applies to its own page and mode.
    func updateLocal(_ template: FreeControlTemplate, name: String, values: FreeControlValues,
                     expectedPageRevision: UInt64, sourceWindow: FreeControlWindow) throws {
        let name = FreeControlTemplate.userName(name)
        guard !name.isEmpty, let page = TablePreferencePage(rawValue: template.sourcePage),
              page.supportsControlLayoutEditing else { throw ControlLayoutError.invalidConfiguration }
        let key = FreeControlArchive.key(page: page, mode: template.mode)
        try transactPage(key: key, expectedRevision: expectedPageRevision) { candidate in
            guard let index = candidate.templates.firstIndex(where: { $0.id == template.id }) else { throw ControlLayoutError.missingTemplate }
            guard candidate.templates[index] == template else { throw ControlLayoutError.conflict }
            candidate.templates[index].baseName = name
            candidate.templates[index].values = values
            candidate.templates[index].sourceWindow = sourceWindow
            candidate.pages[key] = values
            try candidate.changedPage(key, source: template.id)
        }
    }

    func rename(_ template: FreeControlTemplate, to name: String) throws {
        let name = FreeControlTemplate.userName(name)
        guard !name.isEmpty else { throw ControlLayoutError.invalidConfiguration }
        var (candidate, _) = try readLatest()
        guard let index = candidate.templates.firstIndex(where: { $0.id == template.id }) else { throw ControlLayoutError.missingTemplate }
        guard candidate.templates[index] == template else { throw ControlLayoutError.conflict }
        candidate.templates[index].baseName = name
        try publish(candidate)
    }

    func delete(_ template: FreeControlTemplate) throws {
        var (candidate, bytes) = try readLatest()
        guard let index = candidate.templates.firstIndex(where: { $0.id == template.id }) else {
            archive = candidate; loadedBytes = bytes; return
        }
        guard candidate.templates[index] == template else { throw ControlLayoutError.conflict }
        candidate.templates.remove(at: index)
        try publish(candidate)
    }

    /// Explicit conflict escape hatch: retain a copy without applying it to a changed page.
    func saveCopyOnly(_ template: FreeControlTemplate) throws {
        var copy = template
        copy.baseName = FreeControlTemplate.userName(copy.baseName)
        var (candidate, bytes) = try readLatest()
        if let existing = candidate.templates.first(where: { $0.id == template.id }) {
            guard existing == copy else { throw ControlLayoutError.duplicateTemplate }
            archive = candidate; loadedBytes = bytes; return
        }
        candidate.templates.append(copy)
        try publish(candidate)
    }

    func recoverWithDefault() throws {
        let original = try storage.read()
        if let original { try storage.preserve(original) }
        var candidate = FreeControlArchive()
        candidate.revision = archive.revision
        candidate.legacyImportDisabled = true
        // Invalidate every mounted draft, including an empty/default page.
        candidate.pageRevisions = archive.pageRevisions
        for page in TablePreferencePage.allCases {
            for mode in FreeControlLayoutMode.allCases {
                try candidate.changedPage(FreeControlArchive.key(page: page, mode: mode), source: nil)
            }
        }
        try publish(candidate)
        loadError = nil
    }

    /// Called with one complete native measurement pass. The legacy file is never rewritten.
    func migrateMeasuredPage(page: TablePreferencePage, pageTitle: String, mode: FreeControlLayoutMode, domain: ControlLayoutDomain,
                             input: ControlLayoutPlacement.Input, controls: [String: FreeControlLegacyMeasurements.Control],
                             window: FreeControlWindow) throws {
        guard archive.legacyImportDisabled != true, let legacy = legacyArchive, let original = legacyBytes,
              let legacyStorage, page.usesFreeControlLayout else { return }
        guard try legacyStorage.read() == original else { reloadLegacy(); return }
        let fingerprint = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
        let sourceID = legacy.templateID(for: page)
        let sourceName = sourceID.flatMap { legacy.templates[$0]?.name } ?? pageTitle
        var jobs: [(String, String, ControlLayoutArchive, Bool)] = [("page", sourceName, legacy, true)]
        // Preserve both the old standalone template and the effective page with local overrides.
        let activeOverrides = legacy.bindings[page]?.overrides.keys.contains {
            $0.domain == domain && ($0.layer == .common || $0.layer == (mode == .twoD ? .twoD : .threeD))
        } ?? false
        if let sourceID, activeOverrides {
            var standalone = legacy
            standalone.bindings[page] = .init(selection: .template(sourceID))
            jobs.append(("template", sourceName, standalone, false))
        }
        var (candidate, _) = try readLatest()
        if candidate.legacyImportDisabled == true { return }
        let before = candidate
        let pageKey = FreeControlArchive.key(page: page, mode: mode)
        for (kind, name, source, applies) in jobs {
            let key = "\(fingerprint):\(pageKey):\(domain.rawValue):\(kind)"
            if candidate.legacyRecords?[key]?.templateID != nil { continue }
            let result = FreeControlLegacyConverter.convert(source, page: page, mode: mode, domain: domain,
                input: input, controls: controls, window: window)
            if result.pending == nil && result.values.isEmpty { continue }
            let domainName = domain == .phoneLandscape ? "手机横屏" : (domain == .padLandscape ? "平板横屏" : "平板竖屏")
            let recordName = "\(name) · \(pageTitle) · \(domainName)" + (kind == "template" ? " · 原模板" : "")
            var record = FreeControlLegacyRecord(id: key, name: recordName, page: page.rawValue,
                mode: mode, domain: domain, detail: result.pending ?? "已按真实窗口转换")
            if result.pending == nil {
                let id = UUID()
                candidate.templates.append(.init(id: id, baseName: recordName, mode: mode, sourcePage: page.rawValue,
                    values: result.values, sourceWindow: window, sourceTemplateID: sourceID))
                record.templateID = id
                if applies && candidate.pages[pageKey] == nil && candidate.pageRevision(pageKey) == 0 {
                    candidate.pages[pageKey] = result.values
                    try candidate.changedPage(pageKey, source: id)
                }
            }
            if candidate.legacyRecords == nil { candidate.legacyRecords = [:] }
            candidate.legacyRecords?[key] = record
        }
        guard candidate != before else { return }
        if !(candidate.legacyBackups ?? []).contains(fingerprint) {
            try legacyStorage.preserve(original)
            if candidate.legacyBackups == nil { candidate.legacyBackups = [] }
            candidate.legacyBackups?.append(fingerprint)
        }
        try publish(candidate)
    }

    private static func decode(_ bytes: Data) throws -> FreeControlArchive {
        struct Header: Decodable { let schemaVersion: Int }
        let version = try JSONDecoder().decode(Header.self, from: bytes).schemaVersion
        guard version == 2 else { throw ControlLayoutError.unsupportedVersion(version) }
        let candidate = try JSONDecoder().decode(FreeControlArchive.self, from: bytes)
        try candidate.validate()
        return candidate
    }

    private func readLatest() throws -> (FreeControlArchive, Data?) {
        guard loadError == nil else { throw ControlLayoutError.recoveryRequired }
        let bytes = try storage.read()
        let latest = try bytes.map { try Self.decode($0) } ?? FreeControlArchive()
        try latest.validate()
        return (latest, bytes)
    }

    /// Library changes and other pages do not invalidate this page's private draft.
    /// A changed target (including restore-to-identical-values) does invalidate it.
    private func transactPage(key: String, expectedRevision: UInt64,
                              change: (inout FreeControlArchive) throws -> Void) throws {
        var (candidate, _) = try readLatest()
        guard candidate.pageRevision(key) == expectedRevision else { throw ControlLayoutError.conflict }
        try change(&candidate)
        try publish(candidate)
    }

    private func publish(_ next: FreeControlArchive) throws {
        var candidate = next
        guard candidate.revision < UInt64.max else { throw ControlLayoutError.invalidConfiguration }
        candidate.revision += 1
        try candidate.validate()
        let bytes = try JSONEncoder().encode(candidate)
        try storage.writeAtomically(bytes)
        loadedBytes = bytes
        archive = candidate
    }

    private func transact(expectedRevision: UInt64, change: (inout FreeControlArchive) throws -> Void) throws {
        guard loadError == nil else { throw ControlLayoutError.invalidConfiguration }
        guard archive.revision == expectedRevision, try storage.read() == loadedBytes else {
            throw ControlLayoutError.conflict
        }
        var candidate = archive
        try change(&candidate)
        try publish(candidate)
    }
}

/// All callers run on the main actor, including multiple windows and store instances.
/// A single atomic file contains templates, references, and overrides.
@MainActor
protocol ControlLayoutStorage {
    func read() throws -> Data?
    func writeAtomically(_ data: Data) throws
    func preserve(_ data: Data) throws
}

#if DEBUG
/// UI tests can exercise a pristine default without deleting saved device layouts
/// or converting that default into a fixed, user-created template.
@MainActor
private final class EphemeralControlLayoutStorage: ControlLayoutStorage {
    private var data: Data?
    func read() throws -> Data? { data }
    func writeAtomically(_ data: Data) throws { self.data = data }
    func preserve(_ data: Data) throws {}
}
#endif

@MainActor
struct ControlLayoutFileStorage: ControlLayoutStorage {
    let url: URL

    static var application: Self {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return Self(url: root.appendingPathComponent("ControlLayouts/layouts-v1.json"))
    }

    func read() throws -> Data? {
        do { return try Data(contentsOf: url) }
        catch CocoaError.fileReadNoSuchFile { return nil }
    }

    func writeAtomically(_ data: Data) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func preserve(_ data: Data) throws {
        let backup = url.deletingLastPathComponent().appendingPathComponent("recovery-\(UUID().uuidString).json")
        try FileManager.default.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: backup, options: .atomic)
    }
}

@MainActor
final class ControlLayoutStore: ObservableObject {
    static let shared = ControlLayoutStore(storage: ControlLayoutFileStorage.application)
    @Published private(set) var archive = ControlLayoutArchive()
    @Published private(set) var loadError: String?
    private let storage: any ControlLayoutStorage
    private var loadedBytes: Data?

    init(storage: any ControlLayoutStorage) {
        self.storage = storage
        reload()
    }

    /// Failed reads leave the last usable in-memory value and the original file intact.
    func reload() {
        do {
            let bytes = try storage.read()
            let candidate = try bytes.map(Self.decode) ?? ControlLayoutArchive()
            loadedBytes = bytes
            archive = candidate
            loadError = nil
        } catch {
            loadError = error.localizedDescription
            NSLog("ControlLayoutStore: cannot load layout archive: %@", error.localizedDescription)
        }
    }

    static func decode(_ data: Data) throws -> ControlLayoutArchive {
        // Check the format first so newer enum cases cannot obscure the recovery explanation.
        struct Header: Decodable { let schemaVersion: Int }
        let version = try JSONDecoder().decode(Header.self, from: data).schemaVersion
        guard version == 1 else { throw ControlLayoutError.unsupportedVersion(version) }
        let value = try JSONDecoder().decode(ControlLayoutArchive.self, from: data)
        try value.validate()
        return value
    }

    /// Explicit recovery only. Backup failure must prevent replacement of the original.
    func recoverWithDefault() throws {
        let original = try storage.read()
        if let original { try storage.preserve(original) }
        guard archive.revision < UInt64.max - 1 else { throw ControlLayoutError.invalidConfiguration }
        var candidate = ControlLayoutArchive()
        // Recovery is also a revision: drafts opened before it must become stale.
        candidate.revision = archive.revision + 1
        try candidate.validate()
        let bytes = try JSONEncoder().encode(candidate)
        try storage.writeAtomically(bytes)
        loadedBytes = bytes
        archive = candidate
        loadError = nil
    }

    func savePage(_ page: TablePreferencePage, edits: ControlLayoutPatch,
                  restoring: Set<ControlLayoutAddress> = [], expectedRevision: UInt64) throws {
        try requireSupported(page)
        try transact(expectedRevision: expectedRevision) { candidate in
            var binding = candidate.bindings[page] ?? ControlLayoutBinding()
            for address in restoring { binding.overrides.removeValue(forKey: address) }
            binding.overrides.merge(edits) { _, new in new }
            candidate.bindings[page] = binding
        }
    }

    /// The caller retains the ID across retries. Only selected exact layer/property keys
    /// are incorporated and cleared; all other domains and inactive properties survive.
    func saveAs(id: UUID, name: String, page: TablePreferencePage,
                edits: ControlLayoutPatch = [:], incorporating: Set<ControlLayoutAddress>,
                expectedRevision: UInt64) throws {
        try requireSupported(page)
        try transact(expectedRevision: expectedRevision) { candidate in
            guard candidate.templates[id] == nil else { throw ControlLayoutError.duplicateTemplate }
            let sourceID = candidate.templateID(for: page)
            var values = sourceID.flatMap { candidate.templates[$0]?.values } ?? [:]
            var binding = candidate.bindings[page] ?? ControlLayoutBinding()
            binding.overrides.merge(edits) { _, new in new }
            for address in incorporating {
                if let value = binding.overrides.removeValue(forKey: address) { values[address] = value }
            }
            candidate.templates[id] = ControlLayoutTemplate(
                id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), sourceID: sourceID, values: values)
            binding.selection = .template(id)
            candidate.bindings[page] = binding
        }
    }

    func apply(_ selection: ControlLayoutSelection, to page: TablePreferencePage,
               clearing: Set<ControlLayoutAddress> = [], expectedRevision: UInt64) throws {
        try requireSupported(page)
        try transact(expectedRevision: expectedRevision) { candidate in
            var binding = candidate.bindings[page] ?? ControlLayoutBinding()
            binding.selection = selection
            for address in clearing { binding.overrides.removeValue(forKey: address) }
            candidate.bindings[page] = binding
        }
    }

    func restorePage(_ page: TablePreferencePage, usingBuiltIn: Bool, expectedRevision: UInt64) throws {
        try requireSupported(page)
        try transact(expectedRevision: expectedRevision) { candidate in
            candidate.bindings[page] = ControlLayoutBinding(selection: usingBuiltIn ? .builtIn : .familyDefault)
        }
    }

    /// Commit the reviewed binding and optional independent template in one write.
    func save(_ draft: ControlLayoutDraft, newTemplate: (id: UUID, name: String)? = nil) throws {
        guard !draft.isTemplateDraft else { throw ControlLayoutError.invalidConfiguration }
        try requireSupported(draft.page)
        try transact(expectedRevision: draft.base.revision) { candidate in
            var binding = draft.binding
            if let newTemplate {
                guard candidate.templates[newTemplate.id] == nil else { throw ControlLayoutError.duplicateTemplate }
                let sourceID = draft.preview.templateID(for: draft.page)
                var values = sourceID.flatMap { candidate.templates[$0]?.values } ?? [:]
                // The save sheet explicitly describes this domain, preserving all other domains.
                for (address, value) in binding.overrides where address.domain == draft.domain {
                    values[address] = value
                    binding.overrides.removeValue(forKey: address)
                }
                candidate.templates[newTemplate.id] = .init(id: newTemplate.id,
                    name: newTemplate.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    sourceID: sourceID, values: values)
                binding.selection = .template(newTemplate.id)
            }
            candidate.bindings[draft.page] = binding
        }
    }

    func rename(_ id: UUID, name: String, expectedRevision: UInt64) throws {
        try transact(expectedRevision: expectedRevision) { archive in
            guard archive.templates[id] != nil else { throw ControlLayoutError.missingTemplate }
            archive.templates[id]?.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            archive.templates[id]?.revision += 1
        }
    }

    func copy(_ source: UUID?, id: UUID, name: String, expectedRevision: UInt64) throws {
        try transact(expectedRevision: expectedRevision) { archive in
            guard archive.templates[id] == nil else { throw ControlLayoutError.duplicateTemplate }
            if let source, archive.templates[source] == nil { throw ControlLayoutError.missingTemplate }
            archive.templates[id] = .init(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceID: source, values: source.flatMap { archive.templates[$0]?.values } ?? [:])
        }
    }

    func setFamilyDefault(_ family: ControlLayoutFamily, template: UUID?, expectedRevision: UInt64) throws {
        try transact(expectedRevision: expectedRevision) { $0.familyDefaults[family] = template }
    }

    /// Binding changes and explicitly selected override removals form one commit.
    func apply(_ selection: ControlLayoutSelection, to pages: Set<TablePreferencePage>,
               clearing: [TablePreferencePage: Set<ControlLayoutAddress>] = [:], expectedRevision: UInt64) throws {
        for page in pages { try requireSupported(page) }
        try transact(expectedRevision: expectedRevision) { archive in
            for page in pages {
                var binding = archive.bindings[page] ?? .init()
                binding.selection = selection
                for address in clearing[page] ?? [] { binding.overrides.removeValue(forKey: address) }
                archive.bindings[page] = binding
            }
        }
    }

    /// Replace every live reference in the same file. Provenance is historical, not a binding.
    func delete(_ id: UUID, replacingWith replacement: UUID?, expectedRevision: UInt64) throws {
        try transact(expectedRevision: expectedRevision) { archive in
            guard archive.templates[id] != nil else { throw ControlLayoutError.missingTemplate }
            guard replacement != id else { throw ControlLayoutError.invalidConfiguration }
            if let replacement, archive.templates[replacement] == nil { throw ControlLayoutError.missingTemplate }
            for page in archive.bindings.keys {
                if archive.bindings[page]?.selection == .template(id) {
                    archive.bindings[page]?.selection = replacement.map(ControlLayoutSelection.template) ?? .builtIn
                }
            }
            for family in archive.familyDefaults.keys where archive.familyDefaults[family] == id {
                archive.familyDefaults[family] = replacement
            }
            archive.templates.removeValue(forKey: id)
        }
    }

    /// Only reviewed exact keys are promoted. Unselected edits remain page-local.
    func promote(_ draft: ControlLayoutDraft, keys: Set<ControlLayoutAddress>, clearPromoted: Bool) throws {
        guard !draft.isTemplateDraft, let id = draft.preview.templateID(for: draft.page), !keys.isEmpty,
              keys.allSatisfy({ $0.domain == draft.domain && draft.binding.overrides[$0] != nil }) else {
            throw ControlLayoutError.invalidConfiguration
        }
        try transact(expectedRevision: draft.base.revision) { archive in
            guard archive.templates[id] != nil else { throw ControlLayoutError.missingTemplate }
            var binding = draft.binding
            for key in keys {
                archive.templates[id]?.values[key] = binding.overrides[key]
                if clearPromoted { binding.overrides.removeValue(forKey: key) }
            }
            archive.templates[id]?.revision += 1
            archive.bindings[draft.page] = binding
        }
    }

    func saveTemplate(_ draft: ControlLayoutDraft) throws {
        guard let id = draft.templateID else { throw ControlLayoutError.invalidConfiguration }
        try transact(expectedRevision: draft.base.revision) { archive in
            guard archive.templates[id] != nil else { throw ControlLayoutError.missingTemplate }
            archive.templates[id]?.values = draft.binding.overrides
            archive.templates[id]?.revision += 1
        }
    }

    /// Save stale intent as an independent copy against a freshly loaded archive.
    /// Deliberately does not replace any current page binding or family default.
    func preserveCopy(_ draft: ControlLayoutDraft, id: UUID, name: String) throws {
        let source = draft.templateID ?? draft.preview.templateID(for: draft.page)
        var values = source.flatMap { draft.base.templates[$0]?.values } ?? [:]
        if draft.isTemplateDraft { values = draft.binding.overrides }
        else { values.merge(draft.binding.overrides) { _, new in new } }
        reload()
        try transact(expectedRevision: archive.revision) { archive in
            guard archive.templates[id] == nil else { throw ControlLayoutError.duplicateTemplate }
            archive.templates[id] = .init(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceID: source, values: values)
        }
    }

    /// Internal transaction boundary, also used by the manager's later operations.
    /// Validation and encoding complete before any write. Notification follows durable success.
    func transact(expectedRevision: UInt64, _ change: (inout ControlLayoutArchive) throws -> Void) throws {
        guard loadError == nil else { throw ControlLayoutError.recoveryRequired }
        guard archive.revision == expectedRevision, try storage.read() == loadedBytes else {
            throw ControlLayoutError.conflict
        }
        var candidate = archive
        try change(&candidate)
        guard candidate.revision < UInt64.max - 1 else { throw ControlLayoutError.invalidConfiguration }
        candidate.revision = archive.revision + 1
        try candidate.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(candidate)
        try storage.writeAtomically(bytes)
        loadedBytes = bytes
        archive = candidate
    }

    private func requireSupported(_ page: TablePreferencePage) throws {
        guard page.controlLayoutFamily != nil else { throw ControlLayoutError.unsupportedPage }
    }
}
