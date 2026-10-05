//
//  SignInFormView.swift
//  iris
//

import SwiftUI

struct SignInFormView: View {
    @Bindable var viewModel: AuthViewModel
    let focus: FocusState<AuthViewModel.Field?>.Binding
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md + 4) {
            IrisTextField(
                "Correo de la iglesia",
                icon: "envelope",
                text: $viewModel.signInEmail,
                prompt: "nombre@tuiglesia.org",
                kind: .email,
                error: viewModel.error(for: .signInEmail),
                focus: focus,
                field: .signInEmail
            )
            .submitLabel(.next)
            .onSubmit { focus.wrappedValue = .signInPassword }

            IrisTextField(
                "Contraseña",
                icon: "lock",
                text: $viewModel.signInPassword,
                prompt: "Tu contraseña",
                kind: .password,
                error: viewModel.error(for: .signInPassword),
                focus: focus,
                field: .signInPassword
            )
            .submitLabel(.go)
            .onSubmit(onSubmit)

            HStack {
                Spacer()
                Button("¿Olvidaste tu contraseña?", action: viewModel.presentPasswordRecovery)
                    .buttonStyle(.irisLink)
            }
        }
    }
}
