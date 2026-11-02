//
//  AddBlockSheet.swift
//  iris
//

import SwiftUI

/// "Agregar bloque": an extra block for this service only. The computer times it and saves it in Tiempos,
/// but the service keeps its usual blocks (those are edited in Servicios on the computer).
struct AddBlockSheet: View {
    let client: RemoteClient
    let state: RemoteState

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var minutes = 10
    @State private var position: Int?

    private var blocks: [RemoteState.Service.Block] { state.service?.blocks ?? [] }
    private var currentIndex: Int? { blocks.firstIndex { $0.status == .current } }

    /// Never before the running block or one already done.
    private var positions: [Int] { Array(((currentIndex ?? -1) + 1)...blocks.count) }

    /// Right after the running block; before the service starts, at the end.
    private var chosen: Int { position ?? (currentIndex.map { $0 + 1 } ?? blocks.count) }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            SheetHeader("Agregar bloque") { EmptyView() }
            Text("Solo para este servicio: se guarda en Tiempos, pero el servicio conserva sus bloques de siempre.")
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
            TextField("Nombre del bloque (ej. Santa cena)", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)
            Stepper(value: $minutes, in: 1...240) {
                Text("\(minutes) min").font(IrisFont.callout).monospacedDigit()
            }
            .frame(maxWidth: 420)
            Text("Ubicación").font(IrisFont.overline).tracking(IrisTracking.caps).foregroundStyle(IrisColor.textSecondary)
            ScrollView {
                VStack(spacing: IrisSpacing.xxs) {
                    ForEach(positions, id: \.self) { index in
                        Button { position = index } label: {
                            HStack {
                                Text(index == blocks.count ? "Al final" : "Antes de \(blocks[index].name)")
                                    .font(IrisFont.callout)
                                Spacer()
                                if index == chosen { Image(systemName: "checkmark").foregroundStyle(IrisColor.coral) }
                            }
                            .padding(.horizontal, IrisSpacing.sm)
                            .padding(.vertical, IrisSpacing.xs + 2)
                            .background(RoundedRectangle(cornerRadius: IrisRadius.sm).fill(index == chosen ? IrisColor.surfaceRaised : IrisColor.surface))
                        }
                        .buttonStyle(.irisPressable)
                    }
                }
            }
            .scrollIndicators(.hidden)
            HStack {
                Spacer()
                Button {
                    client.send(.addBlock(name: String(trimmedName.prefix(60)), minutes: minutes, at: chosen))
                    dismiss()
                } label: {
                    Text("Agregar").padding(.horizontal, IrisSpacing.md)
                }
                .buttonStyle(.irisPrimary)
                .disabled(trimmedName.isEmpty)
                .fixedSize()
            }
        }
        .padding(IrisSpacing.lg)
        .frame(minWidth: 520, minHeight: 480)
    }
}
