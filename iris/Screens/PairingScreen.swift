//
//  PairingScreen.swift
//  iris
//

import SwiftUI

/// First screen, every time the app opens: type the code the computer shows. Nothing is remembered.
/// The keypad is our own, so the iPad's system keyboard never covers the screen.
struct PairingScreen: View {
    let client: RemoteClient

    private static let length = RemoteProtocol.codeLength
    @State private var code = ""
    @State private var isAskingAddress = false
    @State private var address = ""
    /// Said on this screen only: the address was typed before the code was complete.
    @State private var hint: String?
    /// The error on screen right now; it goes away after a few seconds or with a tap.
    @State private var notice: String?

    private var isConnecting: Bool { client.phase == .connecting }

    var body: some View {
        VStack(spacing: IrisSpacing.lg) {
            IrisWordmark(markSize: 44)

            IrisSurface(padding: IrisSpacing.xl) {
                VStack(spacing: IrisSpacing.lg) {
                    VStack(spacing: IrisSpacing.xs) {
                        Text("Conecta con Iris")
                            .font(IrisFont.title)
                        Text("En la computadora, abre Configuración → «Vincular iPad» y escribe el código que aparece.")
                            .font(IrisFont.callout)
                            .foregroundStyle(IrisColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    codeDisplay
                    keypad

                    Button(action: connect) {
                        if isConnecting {
                            HStack(spacing: IrisSpacing.xs) {
                                ProgressView().tint(IrisColor.textInverse)
                                Text("Buscando Iris…")
                            }
                        } else {
                            Text("Conectar")
                        }
                    }
                    .buttonStyle(.irisPrimary)
                    .disabled(code.count < Self.length || isConnecting)
                }
            }
            .frame(width: IrisSize.authPanelWidth)

            VStack(spacing: IrisSpacing.xxs) {
                Text("La computadora y el iPad deben estar en la misma red Wi-Fi.")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textSecondary)
                Button("¿No la encuentra? Escribe la dirección") { isAskingAddress = true }
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textSecondary)
                    .underline()
            }
        }
        .padding(IrisSpacing.lg)
        // Floating, so a long message never pushes "Escribe la dirección" off the screen; it leaves by itself.
        .overlay(alignment: .top) {
            if let notice {
                IrisBanner(style: .error, message: notice)
                    .background(IrisColor.canvasElevated, in: RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
                    .frame(maxWidth: 560)
                    .padding(.top, IrisSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation(IrisMotion.snappy) { self.notice = nil } }
            }
        }
        .animation(IrisMotion.snappy, value: notice)
        .task(id: notice) {
            guard notice != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            withAnimation(IrisMotion.snappy) { notice = nil }
        }
        .onChange(of: hint) { _, message in if let message { notice = message } }
        .alert("Dirección de la computadora", isPresented: $isAskingAddress) {
            TextField("192.168.1.20", text: $address)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
            Button("Cancelar", role: .cancel) {}
            Button("Conectar") { connect(to: address) }
        } message: {
            Text("La dirección aparece en Configuración → Control desde iPad, en Iris.")
        }
        // A refused code starts over; not finding the computer keeps the digits for the next try.
        .onChange(of: client.failureMessage) { _, message in
            if let message { notice = message }
            if message != nil && client.isCodeRejected { code = "" }
        }
    }

    private func connect() { connect(to: nil) }

    private func connect(to address: String?) {
        guard code.count == Self.length else {
            hint = "Escribe primero el código de 6 dígitos y vuelve a tocar «Conectar»."
            return
        }
        hint = nil
        client.connect(code: code, address: address?.isEmpty == true ? nil : address)
    }

    private var codeDisplay: some View {
        HStack(spacing: IrisSpacing.xs) {
            ForEach(0..<Self.length, id: \.self) { index in
                let digit = index < code.count ? String(Array(code)[index]) : ""
                Text(digit)
                    .font(IrisFont.code)
                    .frame(width: 54, height: 64)
                    .background(IrisColor.surface, in: RoundedRectangle(cornerRadius: IrisRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: IrisRadius.sm)
                            .strokeBorder(index == code.count ? IrisColor.coral : IrisColor.stroke, lineWidth: index == code.count ? 2 : 1)
                    )
            }
        }
    }

    private var keypad: some View {
        let keys: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        return VStack(spacing: IrisSpacing.xs) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: IrisSpacing.xs) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(maxWidth: .infinity, minHeight: 56)
        } else {
            Button {
                guard !isConnecting else { return }
                hint = nil
                if key == "⌫" {
                    if !code.isEmpty { code.removeLast() }
                } else if code.count < Self.length {
                    code.append(key)
                }
            } label: {
                Group {
                    if key == "⌫" { Image(systemName: "delete.left") } else { Text(key) }
                }
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(IrisColor.surface, in: RoundedRectangle(cornerRadius: IrisRadius.md))
            }
            .buttonStyle(.irisPressable)
            .accessibilityLabel(key == "⌫" ? "Borrar" : key)
        }
    }
}

#Preview {
    ZStack {
        IrisBackground().ignoresSafeArea()
        PairingScreen(client: RemoteClient())
    }
    .preferredColorScheme(.dark)
}
