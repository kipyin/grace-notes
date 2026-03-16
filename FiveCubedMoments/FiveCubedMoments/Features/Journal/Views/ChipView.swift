import SwiftUI

struct ChipView: View {
    let label: String
    let isTruncated: Bool
    let onTap: () -> Void

    private static let chipBackground = AppTheme.complete.opacity(0.2)
    private static let maxLabelWidth: CGFloat = 120

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: isTruncated ? Self.maxLabelWidth : nil, alignment: .leading)
                .background(Self.chipBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .mask(
                    Group {
                        if isTruncated {
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.white
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
