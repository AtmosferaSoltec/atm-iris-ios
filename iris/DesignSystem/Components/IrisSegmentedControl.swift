//
//  IrisSegmentedControl.swift
//  iris
//

import SwiftUI

/// Pill-shaped segmented control with a sliding light selection.
struct IrisSegmentedControl<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> LocalizedStringResource

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: IrisSpacing.xxs) {
            ForEach(options) { option in
                let isSelected = option == selection

                Button {
                    withAnimation(IrisMotion.snappy) { selection = option }
                } label: {
                    Text(title(option))
                        .font(IrisFont.calloutEmphasized)
                        .foregroundStyle(isSelected ? IrisColor.textInverse : IrisColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: IrisSize.segmentHeight)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(IrisColor.textPrimary)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(IrisSpacing.xxs)
        .background(IrisColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(IrisColor.stroke))
    }
}
