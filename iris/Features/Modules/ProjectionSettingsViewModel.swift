//
//  ProjectionSettingsViewModel.swift
//  iris
//

import Foundation
import Observation

/// Typeface, size and default background of the projected lyrics (contract §6). Every change
/// saves right away, same as Módulos; a failed save puts the previous value back.
@Observable
final class ProjectionSettingsViewModel: Identifiable {
    private(set) var isLoading = true
    private(set) var settings = ProjectionSettings()
    private(set) var backgrounds: [ProjectionBackground] = []
    private(set) var errorMessage: String?
    /// The latest write, so callers and tests can wait for it.
    private(set) var saveTask: Task<Void, Never>?

    private let repository: any ProjectionSettingsRepository
    private let backgroundRepository: any BackgroundRepository
    private let context: SessionContext

    init(
        repository: any ProjectionSettingsRepository,
        backgroundRepository: any BackgroundRepository,
        session: SessionContext = .preview
    ) {
        self.repository = repository
        self.backgroundRepository = backgroundRepository
        context = session
    }

    /// Same permission as Módulos: both change how every console of the church looks and behaves.
    var canManage: Bool { context.can(.modulesManage) }

    // MARK: Derived

    var defaultBackground: ProjectionBackground? {
        settings.defaultBackgroundId.flatMap { id in backgrounds.first { $0.id == id } }
    }

    /// A sample verse, so the chosen typeface, size and background are seen exactly as the TV would show them.
    var previewFrame: ProjectionFrame {
        ProjectionFrame(
            background: defaultBackground,
            content: .text(
                String(localized: "Sublime gracia del Señor\nque a un pecador salvó"),
                footnote: String(localized: "Sublime Gracia · Estrofa 1")
            )
        )
    }

    var canDecreaseFontSize: Bool { settings.fontSizePt > ProjectionSettings.fontSizeRange.lowerBound }
    var canIncreaseFontSize: Bool { settings.fontSizePt < ProjectionSettings.fontSizeRange.upperBound }

    // MARK: Loading

    func load() async {
        guard isLoading else { return }
        settings = (try? await repository.settings()) ?? ProjectionSettings()
        backgrounds = (try? await backgroundRepository.backgrounds()) ?? []
        isLoading = false
    }

    /// Installs loaded data. Also used by previews to start loaded.
    func apply(settings: ProjectionSettings, backgrounds: [ProjectionBackground]) {
        self.settings = settings
        self.backgrounds = backgrounds
        isLoading = false
    }

    // MARK: Intents

    func selectFontFamily(_ family: ProjectionFontFamily) {
        guard canManage, settings.fontFamily != family else { return }
        save { $0.fontFamily = family }
    }

    func setFontSize(_ pt: Int) {
        let clamped = min(ProjectionSettings.fontSizeRange.upperBound, max(ProjectionSettings.fontSizeRange.lowerBound, pt))
        guard canManage, settings.fontSizePt != clamped else { return }
        save { $0.fontSizePt = clamped }
    }

    func increaseFontSize() { setFontSize(settings.fontSizePt + 4) }
    func decreaseFontSize() { setFontSize(settings.fontSizePt - 4) }

    /// `nil` is "Ninguno": every service starts in black until the operator puts something up.
    func selectDefaultBackground(_ id: ProjectionBackground.ID?) {
        guard canManage, settings.defaultBackgroundId != id else { return }
        save { $0.defaultBackgroundId = id }
    }

    // MARK: Private

    private func save(_ change: (inout ProjectionSettings) -> Void) {
        let previous = settings
        var updated = settings
        change(&updated)
        settings = updated
        errorMessage = nil

        // Saves run one after another so a slower earlier write can never overwrite a newer one.
        let pendingSave = saveTask
        saveTask = Task { [repository] in
            await pendingSave?.value
            do {
                try await repository.save(updated)
            } catch {
                // Revert only if nothing newer was chosen meanwhile.
                if self.settings == updated { self.settings = previous }
                self.errorMessage = String(localized: "Algo salió mal. Inténtalo de nuevo.")
            }
        }
    }
}
