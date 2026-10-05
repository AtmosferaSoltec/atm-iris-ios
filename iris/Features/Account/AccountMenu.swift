//
//  AccountMenu.swift
//  iris
//

import SwiftUI

/// Avatar of the top bar: account details, church switch and sign-out.
struct AccountMenu: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        Menu {
            Section {
                Button {} label: {
                    Text(viewModel.session.fullName)
                    Text(viewModel.session.email)
                }
                .disabled(true)
                Button {} label: {
                    Text(viewModel.session.church.name)
                    Text(viewModel.roleName)
                }
                .disabled(true)
            }

            if viewModel.canSwitchChurch {
                Menu("Cambiar de iglesia", systemImage: "arrow.left.arrow.right") {
                    ForEach(viewModel.otherChurches) { church in
                        Button {
                            viewModel.requestSwitch(to: church)
                        } label: {
                            Text(church.name)
                            Text(church.role.displayName)
                        }
                    }
                }
            }

            Section {
                Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right") {
                    viewModel.requestSignOut()
                }
                Button("Cerrar sesión en todos los dispositivos", systemImage: "iphone.and.arrow.forward", role: .destructive) {
                    viewModel.requestSignOutAll()
                }
            }

            Section("El equipo se administra desde la web.") {}
        } label: {
            avatar
        }
        .accessibilityLabel(Text("Cuenta"))
        .alert(confirmationTitle, isPresented: $viewModel.isConfirming, presenting: viewModel.confirmation) { confirmation in
            Button(confirmButtonTitle(confirmation), role: .destructive) {
                Task { await viewModel.confirm() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { confirmation in
            Text(confirmationMessage(confirmation))
        }
        .alert("No se pudo completar", isPresented: $viewModel.isShowingError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var avatar: some View {
        ZStack {
            Text(viewModel.initials)
                .font(IrisFont.calloutEmphasized)
                .foregroundStyle(IrisColor.textInverse)
                .opacity(viewModel.isWorking ? 0 : 1)
            if viewModel.isWorking {
                ProgressView()
                    .tint(IrisColor.textInverse)
            }
        }
        .frame(width: 42, height: 42)
        .background(IrisGradient.accent, in: Circle())
    }

    private var confirmationTitle: Text {
        switch viewModel.confirmation {
        case .signOutAll: Text("¿Cerrar sesión en todos los dispositivos?")
        case .switchChurch: Text("¿Cambiar de iglesia?")
        case .signOut, nil: Text("¿Cerrar sesión?")
        }
    }

    private func confirmButtonTitle(_ confirmation: AccountViewModel.Confirmation) -> LocalizedStringKey {
        switch confirmation {
        case .signOut: "Cerrar sesión"
        case .signOutAll: "Cerrar todas"
        case .switchChurch: "Cambiar"
        }
    }

    private func confirmationMessage(_ confirmation: AccountViewModel.Confirmation) -> String {
        switch confirmation {
        case let .signOut(pending), let .switchChurch(_, pending):
            viewModel.pendingWarning(pending)
        case .signOutAll:
            String(localized: "Se cerrará la sesión en la web, el iPad y Windows. Tendrás que volver a iniciar sesión en cada uno.")
        }
    }
}

#Preview {
    AccountMenu(viewModel: .preview(churches: 3))
        .padding()
        .background(IrisColor.canvas)
        .preferredColorScheme(.dark)
}
