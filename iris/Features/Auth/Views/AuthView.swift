//
//  AuthView.swift
//  iris
//

import SwiftUI

/// Sign in / sign up entry point: brand hero on the left, form panel on the right.
struct AuthView: View {
    @Bindable var viewModel: AuthViewModel

    @FocusState private var focus: AuthViewModel.Field?

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

                IrisSegmentedControl(
                    options: AuthViewModel.Mode.allCases,
                    selection: $viewModel.mode,
                    title: \.title
                )

                if let message = viewModel.bannerMessage {
                    IrisBanner(style: viewModel.bannerStyle, message: message)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                activeForm

                Button { submit() } label: {
                    Text(viewModel.submitTitle)
                }
                .buttonStyle(.irisPrimary(isLoading: viewModel.isSubmitting))

                if viewModel.mode == .signUp {
                    legalNotice
                }
            }
        }
        .animation(IrisMotion.smooth, value: viewModel.mode)
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
        .id(viewModel.mode)
        .transition(.blurReplace)
    }

    @ViewBuilder
    private var activeForm: some View {
        switch viewModel.mode {
        case .signIn:
            SignInFormView(viewModel: viewModel, focus: $focus, onSubmit: { submit() })
                .transition(.blurReplace)
        case .signUp:
            SignUpFormView(viewModel: viewModel, focus: $focus, onSubmit: { submit() })
                .transition(.blurReplace)
        }
    }

    private var legalNotice: some View {
        Text("Al crear tu cuenta aceptas los [Términos](https://iris.app/terminos) y la [Política de privacidad](https://iris.app/privacidad).")
            .font(IrisFont.caption)
            .foregroundStyle(IrisColor.textTertiary)
            .tint(IrisColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
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

#Preview("Sign up", traits: .landscapeLeft) {
    let viewModel = AuthViewModel(
        authService: MockAuthService(),
        showcaseProvider: StaticShowcaseContentProvider(),
        onAuthenticated: { _ in }
    )
    viewModel.mode = .signUp
    return AuthView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
