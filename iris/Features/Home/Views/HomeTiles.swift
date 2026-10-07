//
//  HomeTiles.swift
//  iris
//

import SwiftUI

/// Entry to Tiempos: only how many services were timed. The details live in Tiempos.
struct TimesTile: View {
    let viewModel: HomeViewModel

    var body: some View {
        IrisTile(
            "Tiempos",
            subtitle: viewModel.timesSubtitle,
            systemImage: "timer",
            tint: IrisColor.coral,
            action: { viewModel.openTimes() }
        )
    }
}

/// Service types and whether each tracks time.
struct ServicesTile: View {
    let viewModel: HomeViewModel

    var body: some View {
        IrisTile(
            "Servicios",
            subtitle: String(localized: "\(viewModel.serviceTypes.count) tipos de servicio"),
            systemImage: "calendar",
            tint: IrisColor.ember,
            action: { viewModel.openServices() }
        ) {
            VStack(spacing: IrisSpacing.sm) {
                ForEach(viewModel.serviceTypes) { type in
                    HStack(spacing: IrisSpacing.sm) {
                        Circle()
                            .fill(Color(hex: type.color))
                            .frame(width: 10, height: 10)
                        Text(type.name)
                            .font(IrisFont.calloutEmphasized)
                            .foregroundStyle(IrisColor.textPrimary)
                        Spacer(minLength: 0)
                        if type.tracksTime && viewModel.modules.timeControl {
                            IrisChip("Con tiempos", systemImage: "timer", tint: IrisColor.success)
                        } else {
                            IrisChip("Solo proyección", tint: IrisColor.textTertiary)
                        }
                    }
                }
            }
        }
    }
}

/// Library counts: lyrics, music on this iPad and web uploads. Opens the Biblioteca screen.
struct LibraryTile: View {
    let viewModel: HomeViewModel

    var body: some View {
        IrisTile("Biblioteca", subtitle: String(localized: "Tu contenido"), systemImage: "square.stack.fill", tint: IrisColor.violet, action: viewModel.openLibrary) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: IrisSpacing.sm), GridItem(.flexible())], spacing: IrisSpacing.sm) {
                count(viewModel.library.lyrics, label: "Letras", kind: .song)
                if viewModel.modules.multimedia {
                    count(viewModel.library.music, label: "Música", kind: .music)
                    count(viewModel.library.media, label: "Multimedia", kind: .image)
                }
            }
        }
    }

    private func count(_ value: Int, label: LocalizedStringKey, kind: ServiceItem.Kind) -> some View {
        HStack(spacing: IrisSpacing.sm) {
            Image(systemName: kind.systemImage)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(kind.tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value, format: .number)
                    .font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit())
                    .foregroundStyle(IrisColor.textPrimary)
                Text(label)
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(IrisSpacing.sm)
        .background(IrisColor.surface, in: RoundedRectangle(cornerRadius: IrisRadius.sm, style: .continuous))
    }
}

/// People who lead blocks.
struct PeopleTile: View {
    let viewModel: HomeViewModel

    var body: some View {
        IrisTile(
            "Personas",
            subtitle: String(localized: "Responsables de bloques"),
            systemImage: "person.2.fill",
            tint: IrisColor.indigo,
            action: { viewModel.openPeople() }
        ) {
            VStack(alignment: .leading, spacing: IrisSpacing.md) {
                HStack(spacing: -10) {
                    ForEach(Array(viewModel.people.prefix(5).enumerated()), id: \.element.id) { index, person in
                        Text(person.initials)
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(IrisColor.textInverse)
                            .frame(width: 40, height: 40)
                            .background(IrisGradient.spectrum[index % IrisGradient.spectrum.count], in: Circle())
                            .overlay(Circle().strokeBorder(IrisColor.canvasElevated, lineWidth: 3))
                    }
                    if viewModel.people.count > 5 {
                        Text("+\(viewModel.people.count - 5)")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(IrisColor.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(IrisColor.surfaceRaised, in: Circle())
                            .overlay(Circle().strokeBorder(IrisColor.canvasElevated, lineWidth: 3))
                    }
                }
                Text("\(viewModel.people.count) personas registradas")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }
        }
    }
}

/// Which parts of Iris the church uses.
struct ModulesTile: View {
    let viewModel: HomeViewModel

    var body: some View {
        IrisTile(
            "Configuración",
            subtitle: String(localized: "Qué usa tu iglesia y cómo se ve"),
            systemImage: "switch.2",
            tint: IrisColor.success,
            action: { viewModel.openModules() }
        ) {
            VStack(spacing: IrisSpacing.sm) {
                row("Letras", isOn: true)
                if viewModel.availableModules.bible {
                    row("Biblia", isOn: viewModel.modules.bible)
                }
                row("Multimedia", isOn: viewModel.modules.multimedia)
                row("Control de tiempo", isOn: viewModel.modules.timeControl)
            }
        }
    }

    private func row(_ title: LocalizedStringKey, isOn: Bool) -> some View {
        HStack {
            Text(title)
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textPrimary)
            Spacer()
            HStack(spacing: IrisSpacing.xxs + 2) {
                Circle()
                    .fill(isOn ? IrisColor.success : IrisColor.textTertiary)
                    .frame(width: 7, height: 7)
                Group {
                    if isOn { Text("Activo") } else { Text("Apagado") }
                }
                .font(IrisFont.caption)
                .foregroundStyle(isOn ? IrisColor.textSecondary : IrisColor.textTertiary)
            }
        }
    }
}
