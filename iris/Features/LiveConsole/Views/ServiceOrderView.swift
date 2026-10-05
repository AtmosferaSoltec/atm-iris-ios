//
//  ServiceOrderView.swift
//  iris
//

import SwiftUI

/// Left column: the run sheet of the service.
/// Swipe a row to delete it, long-press for more actions, drag to reorder.
struct ServiceOrderView: View {
    @Bindable var viewModel: LiveConsoleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            header

            if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label("Servicio vacío", systemImage: "list.bullet.rectangle")
                } description: {
                    if viewModel.showsMultimedia {
                        Text("Toca Agregar para sumar letras, música, imágenes o videos.")
                    } else {
                        Text("Toca Agregar para sumar letras.")
                    }
                }
                .foregroundStyle(IrisColor.textSecondary)
                .frame(maxHeight: .infinity)
            } else {
                list
            }

            Button {
                viewModel.presentAddToService()
            } label: {
                Label("Agregar", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.irisPill)
        }
        .confirmationDialog(
            "¿Vaciar el servicio?",
            isPresented: $viewModel.isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Quitar \(viewModel.items.count) elementos", role: .destructive) {
                withAnimation(IrisMotion.smooth) { viewModel.clearService() }
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    private var header: some View {
        HStack(spacing: IrisSpacing.xs) {
            IrisSectionHeader("SERVICIO") {
                Text(viewModel.items.count, format: .number)
                    .monospacedDigit()
            }

            Menu {
                Button("Vaciar servicio", systemImage: "trash", role: .destructive) {
                    viewModel.requestClearService()
                }
                .disabled(viewModel.items.isEmpty)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(.callout, weight: .bold))
                    .foregroundStyle(IrisColor.textSecondary)
                    .frame(width: 32, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Opciones del servicio"))
        }
        .padding(.leading, IrisSpacing.xs)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: IrisSpacing.xxs) {
                ForEach(viewModel.items) { item in
                    row(for: item)
                }
                .reorderable()
            }
            .reorderContainer(for: ServiceItem.self) { difference in
                var target: ServiceItem.ID?
                if case let .before(id) = difference.destination.position { target = id }
                withAnimation(IrisMotion.smooth) {
                    viewModel.moveItems(Array(difference.sources), before: target)
                }
            }
        }
        .scrollIndicators(.hidden)
        .swipeActionsContainer()
    }

    private func row(for item: ServiceItem) -> some View {
        Button {
            withAnimation(IrisMotion.snappy) { viewModel.selectItem(item.id) }
        } label: {
            ServiceItemRow(
                item: item,
                position: viewModel.position(of: item),
                isSelected: item.id == viewModel.selectedItemID
            )
        }
        .buttonStyle(.irisPressable)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation(IrisMotion.smooth) { viewModel.removeItem(item.id) }
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Duplicar", systemImage: "plus.square.on.square") {
                withAnimation(IrisMotion.smooth) { viewModel.duplicateItem(item.id) }
            }
            Button("Mover arriba", systemImage: "arrow.up") {
                withAnimation(IrisMotion.smooth) { viewModel.moveItem(item.id, by: -1) }
            }
            .disabled(!viewModel.canMove(item.id, by: -1))
            Button("Mover abajo", systemImage: "arrow.down") {
                withAnimation(IrisMotion.smooth) { viewModel.moveItem(item.id, by: 1) }
            }
            .disabled(!viewModel.canMove(item.id, by: 1))
            Divider()
            Button("Eliminar", systemImage: "trash", role: .destructive) {
                withAnimation(IrisMotion.smooth) { viewModel.removeItem(item.id) }
            }
        }
    }
}

struct ServiceItemRow: View {
    let item: ServiceItem
    let position: Int
    let isSelected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)

        HStack(spacing: IrisSpacing.sm) {
            Text(position, format: .number.precision(.integerLength(2)))
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(IrisColor.textTertiary)

            Image(systemName: item.kind.systemImage)
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(item.kind.tint)
                .frame(width: 36, height: 36)
                .background(item.kind.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: IrisRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(IrisFont.calloutEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, IrisSpacing.sm)
        .padding(.vertical, IrisSpacing.sm - 2)
        .background {
            if isSelected {
                shape.fill(IrisColor.surfaceRaised)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(IrisGradient.accent)
                            .frame(width: 3)
                            .padding(.vertical, IrisSpacing.sm)
                    }
            }
        }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
