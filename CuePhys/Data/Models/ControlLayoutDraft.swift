import Foundation

/// A private editing snapshot. Preview and history never publish to the live store.
struct ControlLayoutDraft {
    let page: TablePreferencePage
    let domain: ControlLayoutDomain
    let templateID: UUID?
    let isTemplateDraft: Bool
    private let initialBinding: ControlLayoutBinding
    let base: ControlLayoutArchive
    private(set) var binding: ControlLayoutBinding
    private(set) var undoStack: [ControlLayoutBinding] = []
    private(set) var redoStack: [ControlLayoutBinding] = []

    init(archive: ControlLayoutArchive, page: TablePreferencePage, domain: ControlLayoutDomain, templateID: UUID? = nil, editingTemplate: Bool = false) {
        self.base = archive; self.page = page; self.domain = domain
        self.templateID = templateID
        self.isTemplateDraft = editingTemplate || templateID != nil
        initialBinding = isTemplateDraft ? .init(selection: .builtIn, overrides: templateID.flatMap { archive.templates[$0]?.values } ?? [:])
            : archive.bindings[page] ?? ControlLayoutBinding()
        binding = initialBinding
    }
    var isDirty: Bool { binding != initialBinding }
    var preview: ControlLayoutArchive {
        var archive = base
        archive.bindings[page] = binding
        return archive
    }
    /// A common-layer adjustment starts from the common value, even when the
    /// visible mode has a more specific override. Preview still uses that mode.
    func value(_ group: ControlLayoutGroup, _ property: ControlLayoutProperty,
               editing layer: ControlLayoutLayer) -> ControlLayoutValue? {
        ControlLayoutResolver.resolve(preview, page: page, domain: domain, mode: layer,
                                      capabilities: [group])[group, property]
    }
    mutating func change(_ mutation: (inout ControlLayoutBinding) -> Void) {
        var next = binding
        mutation(&next)
        guard next != binding else { return }
        undoStack.append(binding); redoStack.removeAll(); binding = next
    }
    mutating func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(binding); binding = previous
    }
    mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(binding); binding = next
    }
    func address(_ group: ControlLayoutGroup, _ property: ControlLayoutProperty,
                 layer: ControlLayoutLayer) -> ControlLayoutAddress {
        .init(domain: domain, layer: layer, group: group, property: property)
    }
}
