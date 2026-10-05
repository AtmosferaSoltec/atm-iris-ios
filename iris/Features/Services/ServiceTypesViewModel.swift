//
//  ServiceTypesViewModel.swift
//  iris
//

import Foundation
import Observation

/// The church's service types; opens the editor to create or change one.
@Observable
final class ServiceTypesViewModel {
    // MARK: State

    private(set) var isLoading = true
    private(set) var serviceTypes: [ServiceType] = []
    private(set) var modules = ChurchModules()
    var editor: ServiceTypeEditorViewModel?

    private let serviceTypeRepository: any ServiceTypeRepository
    private let peopleRepository: any PeopleRepository
    private let moduleSettings: any ModuleSettingsRepository
    private let context: SessionContext

    init(
        serviceTypes: any ServiceTypeRepository,
        people: any PeopleRepository,
        moduleSettings: any ModuleSettingsRepository,
        session: SessionContext = .preview
    ) {
        serviceTypeRepository = serviceTypes
        peopleRepository = people
        self.moduleSettings = moduleSettings
        context = session
    }

    /// Without `serviceTypes.manage` there is no "Nuevo servicio" and the editor opens read-only.
    var canManage: Bool { context.can(.serviceTypesManage) }

    /// Reloads silently when a sync changes the types or the modules, until the calling task is cancelled.
    func observeChanges() async {
        for await _ in AsyncStream.merged([serviceTypeRepository.changes(), moduleSettings.changes()]) {
            guard !isLoading else { continue }
            let modules = (try? await moduleSettings.modules()) ?? self.modules
            let types = (try? await serviceTypeRepository.serviceTypes()) ?? serviceTypes
            apply(serviceTypes: types, modules: modules)
        }
    }

    // MARK: Derived

    /// "Domingo · 10:00" or "Sin horario".
    func scheduleText(for type: ServiceType) -> String {
        guard let schedule = type.schedule else { return String(localized: "Sin horario") }
        return IrisScheduleFormat.summary(schedule)
    }

    /// Blocks only show when the church uses time control.
    func showsBlocks(of type: ServiceType) -> Bool {
        modules.timeControl && type.tracksTime
    }

    /// "4 bloques · 1 h y 10 min".
    func blocksSummary(for type: ServiceType) -> String {
        IrisDurationFormat.blocksSummary(count: type.blocks.count, seconds: type.plannedSeconds)
    }

    // MARK: Loading

    func load() async {
        guard isLoading else { return }
        let modules = (try? await moduleSettings.modules()) ?? ChurchModules()
        let types = (try? await serviceTypeRepository.serviceTypes()) ?? []
        apply(serviceTypes: types, modules: modules)
    }

    /// Installs loaded data. Also used by previews to start loaded.
    func apply(serviceTypes: [ServiceType], modules: ChurchModules) {
        self.serviceTypes = serviceTypes
        self.modules = modules
        isLoading = false
    }

    // MARK: Intents

    func createServiceType() {
        guard canManage else { return }
        presentEditor(for: nil)
    }

    func edit(_ type: ServiceType) {
        presentEditor(for: type)
    }

    // MARK: Private

    private func presentEditor(for type: ServiceType?) {
        editor = ServiceTypeEditorViewModel(
            editing: type,
            otherTypes: serviceTypes,
            showsTimeControl: modules.timeControl,
            isReadOnly: !canManage,
            serviceTypes: serviceTypeRepository,
            people: peopleRepository,
            onFinish: { [weak self] outcome in
                self?.finishEditing(outcome)
            }
        )
    }

    /// Mirrors what the repository did, so the list updates without reloading.
    private func finishEditing(_ outcome: ServiceTypeEditorViewModel.Outcome) {
        switch outcome {
        case let .saved(type):
            if let index = serviceTypes.firstIndex(where: { $0.id == type.id }) {
                serviceTypes[index] = type
            } else {
                serviceTypes.append(type)
            }
        case let .deleted(id):
            serviceTypes.removeAll { $0.id == id }
        }
        editor = nil
    }
}
