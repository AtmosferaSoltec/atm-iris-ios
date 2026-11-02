//
//  SheetHeader.swift
//  iris
//

import SwiftUI

/// Title row shared by the sheets: title, optional trailing content and the close button.
struct SheetHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    let trailing: Trailing
    @Environment(\.dismiss) private var dismiss

    init(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: IrisSpacing.sm) {
            Text(title).font(IrisFont.title)
            Spacer()
            trailing
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.irisIcon)
                .accessibilityLabel("Cerrar")
        }
    }
}
