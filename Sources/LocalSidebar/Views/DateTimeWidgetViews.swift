import SwiftUI

struct DateTimeSidebarIcon: View {
    var iconSize: CGFloat
    @State private var now = Date()

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
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .onReceive(timer) { value in
            now = value
        }
    }
}

struct CalendarPopoverView: View {
    @State private var month = Date()

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
                        .foregroundStyle(.secondary)
                }

                ForEach(days, id: \.self) { day in
                    if let day {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.callout)
                            .monospacedDigit()
                            .frame(width: 28, height: 28)
                            .background(isToday(day) ? Color.accentColor.opacity(0.22) : Color.clear)
                            .clipShape(Circle())
                    } else {
                        Color.clear.frame(width: 28, height: 28)
                    }
                }
            }
        }
        .padding(14)
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
