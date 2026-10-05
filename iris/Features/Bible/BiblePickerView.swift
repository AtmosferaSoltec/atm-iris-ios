//
//  BiblePickerView.swift
//  iris
//

import SwiftUI

struct BiblePickerView: View {
    @Bindable var viewModel: BiblePickerViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            header

            if viewModel.availability != .ready {
                availabilityState
            } else {
                steps
            }
        }
        .padding(IrisSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(IrisMotion.smooth, value: viewModel.step)
        .animation(IrisMotion.smooth, value: viewModel.availability)
        .presentationSizing(.form)
        .presentationBackground(IrisColor.canvasElevated)
        .task { await viewModel.load() }
    }

    // MARK: Download

    @ViewBuilder
    private var availabilityState: some View {
        VStack(spacing: IrisSpacing.lg) {
            switch viewModel.availability {
            case let .downloading(progress):
                ProgressView(value: progress)
                    .tint(IrisColor.coral)
                    .frame(maxWidth: 320)
                Text(viewModel.downloadText)
                    .font(IrisFont.callout)
                    .monospacedDigit()
                    .foregroundStyle(IrisColor.textSecondary)
            case .needsConnection:
                downloadProblem(Text("Necesitas conexión para descargar la Biblia la primera vez."))
            case let .failed(message):
                downloadProblem(Text(message))
            case .ready:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func downloadProblem(_ message: Text) -> some View {
        VStack(spacing: IrisSpacing.md) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(IrisGradient.accent)
            message
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("Reintentar") { viewModel.retryDownload() }
                .buttonStyle(.irisGlass)
                .fixedSize()
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var steps: some View {
            switch viewModel.step {
            case .book:
                bookStep
                    .transition(.opacity)
            case .chapter:
                numberGrid(viewModel.chapters) { chapter in
                    Task { await viewModel.selectChapter(chapter) }
                }
                .transition(.opacity)
            case .verse:
                verseStep
                    .transition(.opacity)
            }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: IrisSpacing.md) {
            if viewModel.step != .book {
                Button {
                    viewModel.back()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.irisIcon)
                .accessibilityLabel(Text("Atrás"))
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.title)
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                    .contentTransition(.opacity)
                Text("\(viewModel.instruction) · \(viewModel.translationName)")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.irisIcon)
            .accessibilityLabel(Text("Cerrar"))
        }
    }

    // MARK: Steps

    private var bookStep: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            IrisSegmentedControl(
                options: BibleBook.Testament.allCases,
                selection: $viewModel.testament,
                title: \.title
            )

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: IrisSpacing.sm)], spacing: IrisSpacing.sm) {
                    ForEach(viewModel.filteredBooks) { book in
                        BibleBookCell(book: book) {
                            withAnimation(IrisMotion.smooth) { viewModel.selectBook(book) }
                        }
                    }
                }
                .padding(.vertical, IrisSpacing.xxs)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var verseStep: some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(IrisColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            numberGrid(viewModel.verses) { verse in
                viewModel.selectVerse(verse)
            }
        }
    }

    private func numberGrid(_ numbers: [Int], action: @escaping (Int) -> Void) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: IrisSpacing.sm)], spacing: IrisSpacing.sm) {
                ForEach(numbers, id: \.self) { number in
                    BibleNumberCell(number: number) { action(number) }
                }
            }
            .padding(.vertical, IrisSpacing.xxs)
        }
        .scrollIndicators(.hidden)
    }
}

struct BibleBookCell: View {
    let book: BibleBook
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)

        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(book.name)
                    .font(IrisFont.calloutEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                    .lineLimit(1)
                Text("\(book.chapterCount) cap.")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IrisSpacing.md - 2)
            .padding(.vertical, IrisSpacing.sm)
            .background(IrisColor.surface, in: shape)
            .overlay(shape.strokeBorder(IrisColor.stroke))
            .contentShape(shape)
        }
        .buttonStyle(.irisPressable)
    }
}

struct BibleNumberCell: View {
    let number: Int
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)

        Button(action: action) {
            Text(number, format: .number)
                .font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit())
                .foregroundStyle(IrisColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(IrisColor.surface, in: shape)
                .overlay(shape.strokeBorder(IrisColor.stroke))
                .contentShape(shape)
        }
        .buttonStyle(.irisPressable)
    }
}

#Preview {
    BiblePickerView(viewModel: BiblePickerViewModel(repository: MockBibleRepository()) { _, _, _ in })
        .frame(width: 620, height: 760)
        .background(IrisColor.canvasElevated)
        .preferredColorScheme(.dark)
}

#Preview("Descargando") {
    let viewModel = BiblePickerViewModel(repository: MockBibleRepository()) { _, _, _ in }
    viewModel.apply(availability: .downloading(progress: 0.42))
    return BiblePickerView(viewModel: viewModel)
        .frame(width: 620, height: 760)
        .background(IrisColor.canvasElevated)
        .preferredColorScheme(.dark)
}
