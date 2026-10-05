//
//  PasswordRecoveryView.swift
//  iris
//

import SwiftUI

struct PasswordRecoveryView: View {
    @Bindable var viewModel: PasswordRecoveryViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?

    private enum Field: Hashable { case email }

    private var isSent: Bool { viewModel.phase == .sent }

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

            if isSent {
                sentContent
                    .transition(.blurReplace)
            } else {
                editingContent
                    .transition(.blurReplace)
            }
        }
        .padding(IrisSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(IrisMotion.smooth, value: viewModel.phase)
        .presentationSizing(.form)
        .presentationBackground(IrisColor.canvasElevated)
        .onAppear {
            if viewModel.email.isEmpty { focus = .email }
        }
    }

    private var emblem: some View {
        Image(systemName: isSent ? "envelope.open.fill" : "key.fill")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(IrisGradient.accent)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 64, height: 64)
            .background(IrisColor.surface, in: Circle())
            .overlay(Circle().strokeBorder(IrisColor.stroke))
            .accessibilityHidden(true)
    }

    private var editingContent: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            VStack(alignment: .leading, spacing: IrisSpacing.xs) {
                Text("Recupera tu acceso")
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                Text("Escribe el correo de tu iglesia y te enviaremos un enlace para crear una nueva contraseña.")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }

            IrisTextField(
                "Correo de la iglesia",
                icon: "envelope",
                text: $viewModel.email,
                prompt: "nombre@tuiglesia.org",
                kind: .email,
                error: viewModel.error,
                focus: $focus,
                field: .email
            )
            .submitLabel(.send)
            .onSubmit { send() }

            Button("Enviar enlace") { send() }
                .buttonStyle(.irisPrimary(isLoading: viewModel.isSending))
        }
    }

    private var sentContent: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            VStack(alignment: .leading, spacing: IrisSpacing.xs) {
                Text("Revisa tu correo")
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                Text("Enviamos un enlace a **\(viewModel.trimmedEmail)**. Puede tardar un par de minutos en llegar.")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }

            Button("Volver a iniciar sesión") { dismiss() }
                .buttonStyle(.irisGlass)
        }
    }

    private func send() {
        Task { await viewModel.send() }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PasswordRecoveryView(
                viewModel: PasswordRecoveryViewModel(email: "", authService: MockAuthService())
            )
        }
        .preferredColorScheme(.dark)
}
