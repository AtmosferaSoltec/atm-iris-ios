//
//  IrisTextField.swift
//  iris
//

import SwiftUI
import UIKit

/// Labeled input with a leading icon, spectrum focus ring and inline validation.
/// Focus is driven by the caller's `FocusState`, so forms can chain fields.
struct IrisTextField<Field: Hashable>: View {
    enum Kind {
        case text, name, organization, email, password, newPassword
        /// Emailed numeric code: number pad, large spaced digits.
        case oneTimeCode

        var isSecure: Bool { self == .password || self == .newPassword }

        var contentType: UITextContentType? {
            switch self {
            case .text: nil
            case .name: .name
            case .organization: .organizationName
            case .email: .emailAddress
            case .password: .password
            case .newPassword: .newPassword
            case .oneTimeCode: .oneTimeCode
            }
        }

        var keyboardType: UIKeyboardType {
            switch self {
            case .email: .emailAddress
            case .oneTimeCode: .numberPad
            default: .default
            }
        }

        var font: Font {
            self == .oneTimeCode ? IrisFont.code : IrisFont.body
        }

        var tracking: CGFloat {
            self == .oneTimeCode ? IrisTracking.code : 0
        }

        var autocapitalization: TextInputAutocapitalization {
            switch self {
            case .text: .sentences
            case .name, .organization: .words
            case .email, .password, .newPassword, .oneTimeCode: .never
            }
        }
    }

    private let label: LocalizedStringKey
    private let icon: String
    @Binding private var text: String
    private let prompt: LocalizedStringKey?
    private let kind: Kind
    private let error: String?
    private let hint: LocalizedStringKey?
    private let focus: FocusState<Field?>.Binding
    private let field: Field

    @State private var isRevealed = false

    init(
        _ label: LocalizedStringKey,
        icon: String,
        text: Binding<String>,
        prompt: LocalizedStringKey? = nil,
        kind: Kind = .text,
        error: String? = nil,
        hint: LocalizedStringKey? = nil,
        focus: FocusState<Field?>.Binding,
        field: Field
    ) {
        self.label = label
        self.icon = icon
        self._text = text
        self.prompt = prompt
        self.kind = kind
        self.error = error
        self.hint = hint
        self.focus = focus
        self.field = field
    }

    private var isFocused: Bool { focus.wrappedValue == field }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.xs) {
            Text(label)
                .font(IrisFont.label)
                .foregroundStyle(IrisColor.textSecondary)

            container
            footer
        }
        .animation(IrisMotion.snappy, value: isFocused)
        .animation(IrisMotion.snappy, value: error)
    }

    private var container: some View {
        HStack(spacing: IrisSpacing.sm) {
            Image(systemName: icon)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            input

            if kind.isSecure {
                revealButton
            }
        }
        .padding(.horizontal, IrisSpacing.md + 2)
        .frame(height: IrisSize.controlHeight)
        .background(isFocused ? IrisColor.surfaceRaised : IrisColor.surface, in: shape)
        .overlay {
            shape.strokeBorder(borderStyle, lineWidth: isFocused || error != nil ? 1.5 : 1)
        }
        .shadow(color: isFocused ? IrisColor.coral.opacity(0.22) : .clear, radius: 18)
        .contentShape(shape)
        .onTapGesture { focus.wrappedValue = field }
        .alignmentGuide(.irisFieldCenter) { $0[VerticalAlignment.center] }
    }

    private var input: some View {
        let promptText = prompt.map { Text($0).foregroundStyle(IrisColor.textTertiary) }

        return Group {
            if kind.isSecure && !isRevealed {
                SecureField(text: $text, prompt: promptText) { Text(label) }
            } else {
                TextField(text: $text, prompt: promptText) { Text(label) }
            }
        }
        .font(kind.font)
        .tracking(kind.tracking)
        .foregroundStyle(IrisColor.textPrimary)
        .tint(IrisColor.coral)
        .focused(focus, equals: field)
        .textContentType(kind.contentType)
        .keyboardType(kind.keyboardType)
        .textInputAutocapitalization(kind.autocapitalization)
        .autocorrectionDisabled(kind != .text)
    }

    private var revealButton: some View {
        Button {
            isRevealed.toggle()
        } label: {
            Image(systemName: isRevealed ? "eye.slash" : "eye")
                .font(.system(.callout, weight: .medium))
                .foregroundStyle(IrisColor.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? Text("Ocultar contraseña") : Text("Mostrar contraseña"))
    }

    @ViewBuilder
    private var footer: some View {
        if let error {
            Label(error, systemImage: "exclamationmark.circle.fill")
                .font(IrisFont.caption)
                .foregroundStyle(IrisColor.danger)
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else if let hint {
            Text(hint)
                .font(IrisFont.caption)
                .foregroundStyle(IrisColor.textTertiary)
        }
    }

    private var iconColor: Color {
        if error != nil { return IrisColor.danger }
        return isFocused ? IrisColor.textPrimary : IrisColor.textTertiary
    }

    private var borderStyle: AnyShapeStyle {
        if error != nil { return AnyShapeStyle(IrisColor.danger.opacity(0.8)) }
        if isFocused { return AnyShapeStyle(IrisGradient.accent) }
        return AnyShapeStyle(IrisColor.stroke)
    }
}

extension VerticalAlignment {
    /// Center of an `IrisTextField`'s input box, to line up a button beside it
    /// regardless of the label above or the error below.
    static let irisFieldCenter = VerticalAlignment(IrisFieldCenter.self)
}

nonisolated private enum IrisFieldCenter: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context[VerticalAlignment.center]
    }
}

nonisolated private enum PreviewField: Hashable { case email, password }

#Preview {
    @Previewable @State var email = "pastor@vidanueva.org"
    @Previewable @State var password = ""
    @Previewable @FocusState var focus: PreviewField?

    VStack(spacing: 24) {
        IrisTextField("Correo", icon: "envelope", text: $email, kind: .email, focus: $focus, field: .email)
        IrisTextField(
            "Contraseña", icon: "lock", text: $password, prompt: "Tu contraseña",
            kind: .password, error: "Ingresa tu contraseña.", focus: $focus, field: .password
        )
    }
    .padding(48)
    .frame(width: 480)
    .background(IrisColor.canvas)
}
