import SwiftUI

struct DateTimeSidebarIcon: View {
    var iconSize: CGFloat
    @State private var now = Date()
    @Environment(\.sidebarAppearance) private var appearance

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 1) {
            Text(now, format: .dateTime.weekday(.abbreviated))
                .font(.system(size: max(9, iconSize * 0.24), weight: .semibold))
                .lineLimit(1)

            Text(now, format: .dateTime.day())
                .font(.system(size: max(18, iconSize * 0.52), weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(width: iconSize + 12, height: iconSize + 12)
        .foregroundStyle(appearance.primaryText.color)
        .background(appearance.widgetBackground.color, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(appearance.widgetBorder.color, lineWidth: 1))
        .onReceive(timer) { value in
            now = value
        }
    }
}

struct CalendarPopoverView: View {
    @State private var month = Date()
    @Environment(\.sidebarAppearance) private var appearance

    private var calendar: Calendar {
        .current
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    month = calendar.date(byAdding: .month, value: -1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(month, format: .dateTime.month(.wide).year())
                    .font(.headline)

                Spacer()

                Button {
                    month = calendar.date(byAdding: .month, value: 1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(appearance.secondaryText.color)
                }

                ForEach(days, id: \.self) { day in
                    if let day {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.callout)
                            .monospacedDigit()
                            .frame(width: 28, height: 28)
                            .background(isToday(day) ? appearance.calendarHighlight.color : Color.clear)
                            .clipShape(Circle())
                    } else {
                        Color.clear.frame(width: 28, height: 28)
                    }
                }
            }
        }
        .padding(14)
        .foregroundStyle(appearance.primaryText.color)
        .background(appearance.popoverSurface.color)
    }

    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
            let range = calendar.range(of: .day, in: .month, for: month)
        else {
            return []
        }

        let leading = calendar.component(.weekday, from: interval.start) - calendar.firstWeekday
        let normalizedLeading = (leading + 7) % 7
        let blanks = Array<Date?>(repeating: nil, count: normalizedLeading)
        let monthDays = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }

        return blanks + monthDays
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
}
