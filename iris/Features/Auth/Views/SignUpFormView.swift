//
//  SignUpFormView.swift
//  iris
//

import SwiftUI

struct SignUpFormView: View {
    @Bindable var viewModel: AuthViewModel
    let focus: FocusState<AuthViewModel.Field?>.Binding
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md + 4) {
            IrisTextField(
                "Nombre de la iglesia",
                icon: "building.columns",
                text: $viewModel.churchName,
                prompt: "Iglesia Vida Nueva",
                kind: .organization,
                error: viewModel.error(for: .churchName),
                focus: focus,
                field: .churchName
            )
            .submitLabel(.next)
            .onSubmit { focus.wrappedValue = .leaderName }

            IrisTextField(
                "Responsable",
                icon: "person",
                text: $viewModel.leaderName,
                prompt: "Nombre y apellido",
                kind: .name,
                error: viewModel.error(for: .leaderName),
                focus: focus,
                field: .leaderName
            )
            .submitLabel(.next)
            .onSubmit { focus.wrappedValue = .signUpEmail }

            IrisTextField(
                "Correo de la iglesia",
                icon: "envelope",
                text: $viewModel.signUpEmail,
                prompt: "nombre@tuiglesia.org",
                kind: .email,
                error: viewModel.error(for: .signUpEmail),
                focus: focus,
                field: .signUpEmail
            )
            .submitLabel(.next)
            .onSubmit { focus.wrappedValue = .signUpPassword }

            IrisTextField(
                "Contraseña",
                icon: "lock",
                text: $viewModel.signUpPassword,
                prompt: "Crea una contraseña",
                kind: .newPassword,
                error: viewModel.error(for: .signUpPassword),
                hint: "Mínimo \(AuthValidator.minimumPasswordLength) caracteres.",
                focus: focus,
                field: .signUpPassword
            )
            .submitLabel(.join)
            .onSubmit(onSubmit)
        }
    }
}
