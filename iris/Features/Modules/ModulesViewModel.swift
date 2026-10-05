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
    private(set) var errorMessage: String?
    /// The latest write, so callers and tests can wait for it.
    private(set) var saveTask: Task<Void, Never>?

    private let repository: any ModuleSettingsRepository

    init(moduleSettings: any ModuleSettingsRepository) {
        repository = moduleSettings
    }

    // MARK: Derived

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

    func load() async {
        guard isLoading else { return }
        do {
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
        guard !module.isAlwaysOn, self.isOn(module) != isOn else { return }
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
