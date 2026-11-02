//
//  LeaderSheet.swift
//  iris
//

import SwiftUI

/// "¿Quién dirige…?": pick someone, or type a new name and it joins the people on the computer.
struct LeaderSheet: View {
    let client: RemoteClient
    let state: RemoteState
    let blockIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var block: RemoteState.Service.Block? {
        guard let blocks = state.service?.blocks, blocks.indices.contains(blockIndex) else { return nil }
        return blocks[blockIndex]
    }

    private var matches: [RemoteState.Named] {
        let people = state.people ?? []
        let query = search.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? people : people.filter { $0.name.localizedStandardContains(query) }
    }

    private var newName: String? {
        let name = search.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !(state.people ?? []).contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else { return nil }
        return name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            SheetHeader("¿Quién dirige \(block?.name ?? "el bloque")?") { EmptyView() }
            TextField("Buscar o escribir un nombre", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)
            ScrollView {
                VStack(spacing: IrisSpacing.xxs) {
                    if let newName {
                        row(title: "Agregar «\(newName)»", icon: "person.badge.plus", isSelected: false) {
                            client.send(.setLeader(block: blockIndex, personId: nil, name: newName))
                            dismiss()
                        }
                    }
                    ForEach(matches) { person in
                        row(title: person.name, icon: "person", isSelected: person.id == block?.leaderId) {
                            client.send(.setLeader(block: blockIndex, personId: person.id, name: nil))
                            dismiss()
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(IrisSpacing.lg)
        .frame(minWidth: 520, minHeight: 480)
    }

    private func row(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: IrisSpacing.sm) {
                Image(systemName: icon).frame(width: 24).foregroundStyle(IrisColor.coral)
                Text(title).font(IrisFont.callout)
                Spacer()
                if isSelected { Image(systemName: "checkmark").foregroundStyle(IrisColor.coral) }
            }
            .padding(.horizontal, IrisSpacing.sm)
            .padding(.vertical, IrisSpacing.xs + 2)
            .background(RoundedRectangle(cornerRadius: IrisRadius.sm).fill(isSelected ? IrisColor.surfaceRaised : IrisColor.surface))
        }
        .buttonStyle(.irisPressable)
    }
}
