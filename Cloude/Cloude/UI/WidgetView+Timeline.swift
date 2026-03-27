import SwiftUI

struct TimelineWidget: View {
    let data: [String: Any]

    private var title: String? { data["title"] as? String }
    private var events: [(date: String, title: String, description: String?, icon: String, color: Color)] {
        guard let arr = data["events"] as? [[String: Any]] else { return [] }
        return arr.compactMap { e in
            guard let date = e["date"] as? String, let title = e["title"] as? String else { return nil }
            let icon = e["icon"] as? String ?? "circle.fill"
            let color = parseColor(e["color"] as? String)
            return (date: date, title: title, description: e["description"] as? String, icon: icon, color: color)
        }
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "calendar.day.timeline.left", title: title ?? "Timeline", color: .blue)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                    HStack(alignment: .top, spacing: DS.Spacing.m) {
                        VStack(spacing: 0) {
                            Image(systemName: event.icon)
                                .font(.system(size: DS.Text.s, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: DS.Size.m, height: DS.Size.m)
                                .background(event.color, in: Circle())

                            if index < events.count - 1 {
                                Rectangle()
                                    .fill(event.color.opacity(DS.Opacity.m))
                                    .frame(width: DS.Spacing.xs)
                                    .frame(maxHeight: .infinity)
                            }
                        }

                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(event.date)
                                .font(.system(size: DS.Text.s, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(event.title)
                                .font(.system(size: DS.Text.m, weight: .semibold))
                            if let desc = event.description {
                                Text(desc)
                                    .font(.system(size: DS.Text.m))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, index < events.count - 1 ? DS.Spacing.l : 0)
                    }
                }
            }
        }
    }

    private func parseColor(_ name: String?) -> Color {
        .fromName(name)
    }
}
