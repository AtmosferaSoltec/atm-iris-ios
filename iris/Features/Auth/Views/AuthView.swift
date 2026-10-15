//
//  AuthView.swift
//  iris
//

import SwiftUI

/// Sign-in entry point (accounts are created on the web): brand hero on the left, form panel on the right.
struct AuthView: View {
    @Bindable var viewModel: AuthViewModel

    @FocusState private var focus: AuthViewModel.Field?
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { proxy in
            layout(height: proxy.size.height)
        }
        .background { IrisBackground(isAnimated: false) }
        .task { await viewModel.runShowcase() }
        .onChange(of: viewModel.focusRequest) { _, field in
            guard let field else { return }
            focus = field
            viewModel.focusRequestHandled()
        }
        .sheet(item: $viewModel.recoveryViewModel) { recovery in
            PasswordRecoveryView(viewModel: recovery)
        }
    }

    // MARK: Layout

    private func layout(height: CGFloat) -> some View {
        HStack(spacing: IrisSpacing.xxxl) {
            AuthHeroView(showcaseItem: viewModel.currentShowcaseItem)
                .padding(.vertical, IrisSpacing.xl)

            ScrollView {
                formPanel
                    .padding(.vertical, IrisSpacing.lg)
                    .frame(minHeight: height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: IrisSize.authPanelWidth)
        }
        .padding(.horizontal, IrisSpacing.xxxl)
    }

    // MARK: Form panel

    private var formPanel: some View {
        IrisSurface {
            VStack(alignment: .leading, spacing: IrisSpacing.lg) {
                panelHeader

                if let message = viewModel.bannerMessage {
                    IrisBanner(style: viewModel.bannerStyle, message: message)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                SignInFormView(viewModel: viewModel, focus: $focus, onSubmit: { submit() })

                Button { submit() } label: {
                    Text(viewModel.submitTitle)
                }
                .buttonStyle(.irisPrimary(isLoading: viewModel.isSubmitting))

                createAccountOnWeb
            }
        }
        .animation(IrisMotion.snappy, value: viewModel.bannerMessage)
    }

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.xs) {
            Text(viewModel.headline)
                .font(IrisFont.title)
                .foregroundStyle(IrisColor.textPrimary)
            Text(viewModel.subtitle)
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Accounts are created on the web only.
    private var createAccountOnWeb: some View {
        VStack(spacing: IrisSpacing.xs) {
            Text("¿Tu iglesia aún no tiene cuenta?")
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
            Button { openURL(WebLinks.app) } label: {
                Text("Crea tu cuenta en la web")
            }
            .buttonStyle(.irisLink)
        }
        .frame(maxWidth: .infinity)
    }

    private func submit() {
        focus = nil
        Task { await viewModel.submit() }
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    AuthView(
        viewModel: AuthViewModel(
            authService: MockAuthService(),
            showcaseProvider: StaticShowcaseContentProvider(),
            onAuthenticated: { _ in }
        )
    )
    .preferredColorScheme(.dark)
}
