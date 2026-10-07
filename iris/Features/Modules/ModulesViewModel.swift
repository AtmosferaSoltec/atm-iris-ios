//
//  ModulesViewModel.swift
//  iris
//

import Foundation
import Observation

/// Turns the church's modules on and off. Every change is saved right away.
@Observable
final class ModulesViewModel {
    enum Module: CaseIterable, Identifiable {
        case lyrics, bible, multimedia, timeControl

        var id: Self { self }

        /// Letras cannot be turned off.
        var isAlwaysOn: Bool { self == .lyrics }
    }

    // MARK: State

    private(set) var isLoading = true
    private(set) var modules = ChurchModules()
    /// What exists in Iris today; a module switched off for all of Iris is not listed.
    private(set) var available = ChurchModules()
    private(set) var errorMessage: String?
    /// The latest write, so callers and tests can wait for it.
    private(set) var saveTask: Task<Void, Never>?

    /// Built and shown when "Proyección" is tapped.
    var projectionSheet: ProjectionSettingsViewModel?

    private let repository: any ModuleSettingsRepository
    private let projectionSettings: any ProjectionSettingsRepository
    private let backgroundRepository: any BackgroundRepository
    private let context: SessionContext

    init(
        moduleSettings: any ModuleSettingsRepository,
        projectionSettings: any ProjectionSettingsRepository = MockProjectionSettingsRepository(store: InMemoryChurchStore()),
        backgroundRepository: any BackgroundRepository = MockBackgroundRepository(),
        session: SessionContext = .preview
    ) {
        repository = moduleSettings
        self.projectionSettings = projectionSettings
        self.backgroundRepository = backgroundRepository
        context = session
    }

    func presentProjectionSettings() {
        projectionSheet = ProjectionSettingsViewModel(
            repository: projectionSettings, backgroundRepository: backgroundRepository, session: context
        )
    }

    /// Only roles with `modules.manage` can flip the switches; the rest see them disabled.
    var canManage: Bool { context.can(.modulesManage) }

    // MARK: Derived

    /// The switches on screen: Letras and whatever Iris offers today.
    var visibleModules: [Module] {
        Module.allCases.filter { module in
            switch module {
            case .lyrics: true
            case .bible: available.bible
            case .multimedia: available.multimedia
            case .timeControl: available.timeControl
            }
        }
    }

    func isOn(_ module: Module) -> Bool {
        switch module {
        case .lyrics: true
        case .bible: modules.bible
        case .multimedia: modules.multimedia
        case .timeControl: modules.timeControl
        }
    }

    /// Reassures that turning time control off keeps the saved times.
    var showsTimeControlNote: Bool { !modules.timeControl }

    // MARK: Intents

    /// Follows changes from a sync while the screen is open, until the calling task is cancelled.
    func observeChanges() async {
        for await _ in repository.changes() {
            available = await repository.availableModules()
            if let modules = try? await repository.modules(), saveTask == nil || modules == self.modules {
                self.modules = modules
            }
        }
    }

    func load() async {
        guard isLoading else { return }
        do {
            available = await repository.availableModules()
            apply(modules: try await repository.modules())
        } catch {
            errorMessage = String(localized: "Algo salió mal. Inténtalo de nuevo.")
            isLoading = false
        }
    }

    /// Installs loaded data. Also used by previews to start loaded.
    func apply(modules: ChurchModules) {
        self.modules = modules
        isLoading = false
    }

    /// Updates the switch immediately and saves in the background; a failed save puts it back.
    func setModule(_ module: Module, isOn: Bool) {
        guard canManage, !module.isAlwaysOn, self.isOn(module) != isOn else { return }
        let previous = modules
        switch module {
        case .lyrics: break
        case .bible: modules.bible = isOn
        case .multimedia: modules.multimedia = isOn
        case .timeControl: modules.timeControl = isOn
        }
        errorMessage = nil

        let updated = modules
        // Saves run one after another so a slower earlier write can never overwrite a newer one.
        let pendingSave = saveTask
        saveTask = Task { [repository] in
            await pendingSave?.value
            do {
                try await repository.save(updated)
            } catch {
                // Revert only if nothing newer was chosen meanwhile.
                if self.modules == updated { self.modules = previous }
                self.errorMessage = String(localized: "Algo salió mal. Inténtalo de nuevo.")
            }
        }
    }
}
