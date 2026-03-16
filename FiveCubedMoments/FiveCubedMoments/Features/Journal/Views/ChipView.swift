import SwiftUI

struct ChipView: View {
    let label: String
    let isTruncated: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    @State private var showDeleteButton = false

    private static let chipBackground = AppTheme.complete.opacity(0.2)
    private static let maxLabelWidth: CGFloat = 120

    init(label: String, isTruncated: Bool, onTap: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.label = label
        self.isTruncated = isTruncated
        self.onTap = onTap
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
            .onLongPressGesture {
                if onDelete != nil { showDeleteButton = true }
            }

            if showDeleteButton, let delete = onDelete {
                Button {
                    delete()
                    showDeleteButton = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
            }
        }
    }
}
