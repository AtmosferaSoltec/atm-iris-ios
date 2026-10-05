//
//  ConsoleTopBar.swift
//  iris
//

import SwiftUI

/// App top bar shared by Home and the console.
/// Shows a back button and the service title only inside a service.
struct ConsoleTopBar: View {
    var title: String?
    var date: Date?
    let display: ExternalDisplay?
    let churchName: String
    let initials: String
    var onExit: (() -> Void)?
    let onSignOut: () -> Void

    var body: some View {
        HStack(spacing: IrisSpacing.lg) {
            if let onExit {
                Button {
                    onExit()
                } label: {
                    Label("Inicio", systemImage: "chevron.left")
                }
                .buttonStyle(.irisPill)
            }

            IrisWordmark(markSize: 24)

            if let title {
                Rectangle()
                    .fill(IrisColor.stroke)
                    .frame(width: 1, height: 28)

                serviceTitle(title)
            }

            Spacer(minLength: IrisSpacing.md)

            clock
            displayStatus
            accountMenu
        }
        .padding(.horizontal, IrisSpacing.lg)
        .frame(height: 68)
    }

    private func serviceTitle(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(IrisFont.bodyEmphasized)
                .foregroundStyle(IrisColor.textPrimary)
                .lineLimit(1)
            if let date {
                Text("\(date, format: .dateTime.weekday(.wide).day().month(.wide)) · \(date, format: .dateTime.hour().minute())")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
            }
        }
    }

    private var clock: some View {
        TimelineView(.everyMinute) { context in
            Text(context.date, format: .dateTime.hour().minute())
                .font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit())
                .foregroundStyle(IrisColor.textPrimary)
        }
    }

    private var displayStatus: some View {
        HStack(spacing: IrisSpacing.sm - 2) {
            Image(systemName: "tv")
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(display == nil ? IrisColor.warning : IrisColor.success)

            displayDetails
        }
        .padding(.horizontal, IrisSpacing.md - 2)
        .frame(height: 46)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayAccessibilityLabel)
    }

    private var displayAccessibilityLabel: Text {
        if let display {
            Text("\(display.name), \(display.resolution)")
        } else {
            Text("Sin pantalla. Conecta un TV")
        }
    }

    private var displayDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let display {
                Text(display.name)
                    .font(IrisFont.label)
                    .foregroundStyle(IrisColor.textPrimary)
                Text(display.resolution)
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
            } else {
                Text("Sin pantalla")
                    .font(IrisFont.label)
                    .foregroundStyle(IrisColor.textPrimary)
                Text("Conecta un TV")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
            }
        }
    }

    private var accountMenu: some View {
        Menu {
            Section(churchName) {
                Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    onSignOut()
                }
            }
        } label: {
            Text(initials)
                .font(IrisFont.calloutEmphasized)
                .foregroundStyle(IrisColor.textInverse)
                .frame(width: 42, height: 42)
                .background(IrisGradient.accent, in: Circle())
        }
        .accessibilityLabel(Text("Cuenta"))
    }
}
