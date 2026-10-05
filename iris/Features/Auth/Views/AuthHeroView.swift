//
//  AuthHeroView.swift
//  iris
//

import SwiftUI

/// Brand statement shown next to the auth form.
struct AuthHeroView: View {
    let showcaseItem: ShowcaseItem?

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.xxl) {
            IrisWordmark()

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: IrisSpacing.md) {
                Text("PROYECCIÓN PARA IGLESIAS")
                    .font(IrisFont.overline)
                    .tracking(IrisTracking.overline)
                    .foregroundStyle(IrisGradient.accent)

                Text("Que cada palabra \(Text("ilumine").foregroundStyle(IrisGradient.accent)) el templo.")
                    .font(IrisFont.display)
                    .tracking(IrisTracking.tight)
                    .foregroundStyle(IrisColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Letras, versículos y multimedia en la pantalla grande. Tú diriges todo desde el iPad.")
                    .font(IrisFont.subtitle)
                    .foregroundStyle(IrisColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460, alignment: .leading)
            }

            ProjectionPreview(item: showcaseItem)
                .frame(maxWidth: 440)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
