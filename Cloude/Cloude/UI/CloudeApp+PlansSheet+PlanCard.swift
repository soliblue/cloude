import SwiftUI
import CloudeShared

struct PlanCard: View {
    let plan: PlanItem
    let stage: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let icon = plan.icon {
                            Image(systemName: icon)
                                .font(.footnote)
                                .foregroundColor(.accentColor)
                        }
                        Text(plan.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                    }

                    if let description = plan.description {
                        Text(description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    if let tags = plan.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(planTagColor(tag).opacity(0.1))
                                        .foregroundColor(planTagColor(tag).opacity(0.8))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                if stage == "done", let build = plan.build {
                    Text("\(build)")
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.06))
                        .foregroundColor(.secondary.opacity(0.6))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white.opacity(0.08))
            .cornerRadius(9)
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
