import SwiftUI
import CloudeShared

struct PlanCard: View {
    let plan: PlanItem
    let stage: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.s) {
                        if let icon = plan.icon {
                            Image(systemName: icon)
                                .font(.system(size: DS.Text.m))
                                .foregroundColor(.accentColor)
                        }
                        Text(plan.title)
                            .font(.system(size: DS.Text.m, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                    }

                    if let description = plan.description {
                        Text(description)
                            .font(.system(size: DS.Text.s))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    if let tags = plan.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Spacing.s) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: DS.Text.s, weight: .medium))
                                        .padding(.horizontal, DS.Spacing.s)
                                        .padding(.vertical, DS.Spacing.xs)
                                        .foregroundColor(planTagColor(tag).opacity(DS.Opacity.l))
                                        .clipShape(Capsule())
                                        .glassEffect(.regular.interactive(), in: Capsule())
                                }
                            }
                        }
                        .padding(.top, DS.Spacing.xs)
                    }
                }

                if stage == "done", let build = plan.build {
                    Text("\(build)")
                        .font(.system(size: DS.Text.s, weight: .medium).monospacedDigit())
                        .padding(.horizontal, DS.Spacing.s)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(.white.opacity(DS.Opacity.s))
                        .foregroundColor(.secondary.opacity(DS.Opacity.l))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.l)
        }
        .buttonStyle(.plain)
    }
}
