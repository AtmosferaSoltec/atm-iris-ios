//
//  PasswordRecoveryView.swift
//  iris
//

import SwiftUI

/// Recovery modal in three steps: email, emailed code, new password.
struct PasswordRecoveryView: View {
    @Bindable var viewModel: PasswordRecoveryViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: PasswordRecoveryViewModel.Field?

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.xl) {
            HStack(alignment: .top) {
                emblem
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.irisIcon)
                .accessibilityLabel(Text("Cerrar"))
            }

            VStack(alignment: .leading, spacing: IrisSpacing.lg) {
                stepHeader

                if let message = viewModel.bannerMessage {
                    IrisBanner(style: .error, message: message)
                        .transition(.opacity)
                }

                stepContent
                    .id(viewModel.phase)
                    .transition(.blurReplace)
            }
        }
        .padding(IrisSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(IrisMotion.smooth, value: viewModel.phase)
        .animation(IrisMotion.snappy, value: viewModel.bannerMessage)
        .presentationSizing(.form)
        .presentationBackground(IrisColor.canvasElevated)
        .onAppear { focusCurrentStep() }
        .onChange(of: viewModel.phase) { _, phase in
            if phase == .done {
                dismiss()
            } else {
                focusCurrentStep()
            }
        }
    }

    // MARK: Header

    private var emblemSymbol: String {
        switch viewModel.phase {
        case .email: "key.fill"
        case .code: "envelope.open.fill"
        case .newPassword, .done: "lock.fill"
        }
    }

    private var emblem: some View {
        Image(systemName: emblemSymbol)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(IrisGradient.accent)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 64, height: 64)
            .background(IrisColor.surface, in: Circle())
            .overlay(Circle().strokeBorder(IrisColor.stroke))
            .accessibilityHidden(true)
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.xs) {
            Text("Paso \(viewModel.stepNumber) de 3")
                .font(IrisFont.overline)
                .tracking(IrisTracking.overline)
                .textCase(.uppercase)
                .foregroundStyle(IrisColor.textTertiary)
                .contentTransition(.numericText())
            stepTitle
                .font(IrisFont.title)
                .foregroundStyle(IrisColor.textPrimary)
            stepDescription
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var stepTitle: some View {
        switch viewModel.phase {
        case .email: Text("Recupera tu acceso")
        case .code: Text("Revisa tu correo")
        case .newPassword, .done: Text("Crea tu nueva contraseña")
        }
    }

    @ViewBuilder
    private var stepDescription: some View {
        switch viewModel.phase {
        case .email:
            Text("Escribe el correo de tu iglesia y te enviaremos un código para crear una nueva contraseña.")
        case .code:
            Text("Si **\(viewModel.trimmedEmail)** tiene una cuenta de Iris, te llegó un código. Vence en 15 minutos.")
        case .newPassword, .done:
            Text("Usa al menos \(AuthValidator.minimumPasswordLength) caracteres. Cerraremos la sesión en tus otros dispositivos.")
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.phase {
        case .email: emailStep
        case .code: codeStep
        case .newPassword, .done: passwordStep
        }
    }

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            IrisTextField(
                "Correo de la iglesia",
                icon: "envelope",
                text: $viewModel.email,
                prompt: "nombre@tuiglesia.org",
                kind: .email,
                error: viewModel.error(for: .email),
                focus: $focus,
                field: .email
            )
            .submitLabel(.send)
            .onSubmit { perform { await viewModel.sendCode() } }

            Button("Enviar código") { perform { await viewModel.sendCode() } }
                .buttonStyle(.irisPrimary(isLoading: viewModel.isWorking))
        }
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            IrisTextField(
                "Código",
                icon: "number",
                text: $viewModel.code,
                prompt: "000000",
                kind: .oneTimeCode,
                error: viewModel.error(for: .code),
                focus: $focus,
                field: .code
            )
            .submitLabel(.continue)
            .onSubmit { perform { await viewModel.verifyCode() } }

            Button("Continuar") { perform { await viewModel.verifyCode() } }
                .buttonStyle(.irisPrimary(isLoading: viewModel.isWorking))

            HStack {
                Button("Cambiar correo") { viewModel.editEmail() }
                    .buttonStyle(.irisLink)
                Spacer()
                resendButton
            }
        }
    }

    @ViewBuilder
    private var resendButton: some View {
        if viewModel.resendCountdown > 0 {
            Text("Reenviar código en \(viewModel.resendCountdown) s")
                .font(IrisFont.callout)
                .monospacedDigit()
                .foregroundStyle(IrisColor.textTertiary)
                .contentTransition(.numericText(countsDown: true))
        } else {
            Button("Reenviar código") { perform { await viewModel.resendCode() } }
                .buttonStyle(.irisLink)
                .disabled(!viewModel.canResend)
        }
    }

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            IrisTextField(
                "Nueva contraseña",
                icon: "lock",
                text: $viewModel.password,
                prompt: "Crea una contraseña",
                kind: .newPassword,
                error: viewModel.error(for: .password),
                focus: $focus,
                field: .password
            )
            .submitLabel(.next)
            .onSubmit { focus = .confirmation }

            IrisTextField(
                "Confirmar contraseña",
                icon: "lock",
                text: $viewModel.confirmation,
                prompt: "Repite la contraseña",
                kind: .newPassword,
                error: viewModel.error(for: .confirmation),
                focus: $focus,
                field: .confirmation
            )
            .submitLabel(.done)
            .onSubmit { perform { await viewModel.savePassword() } }

            Button("Guardar") { perform { await viewModel.savePassword() } }
                .buttonStyle(.irisPrimary(isLoading: viewModel.isWorking))
        }
    }

    // MARK: Private

    private func focusCurrentStep() {
        switch viewModel.phase {
        case .email: if viewModel.email.isEmpty { focus = .email }
        case .code: focus = .code
        case .newPassword: focus = .password
        case .done: focus = nil
        }
    }

    private func perform(_ action: @escaping () async -> Void) {
        Task { await action() }
    }
}

#Preview("Paso 1") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PasswordRecoveryView(viewModel: .preview(.email))
        }
        .preferredColorScheme(.dark)
}

#Preview("Paso 2") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PasswordRecoveryView(viewModel: .preview(.code))
        }
        .preferredColorScheme(.dark)
}

#Preview("Paso 3") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PasswordRecoveryView(viewModel: .preview(.newPassword))
        }
        .preferredColorScheme(.dark)
}
