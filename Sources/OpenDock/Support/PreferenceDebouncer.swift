import Foundation

public final class PreferenceDebouncer {
    private var workItems: [String: DispatchWorkItem] = [:]
    private let delay: TimeInterval

    public init(delay: TimeInterval = 0.12) {
        self.delay = delay
    }

    public var pendingIDs: Set<String> {
        Set(workItems.keys)
    }

    public func schedule(id: String, action: @escaping () -> Void) {
        workItems[id]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.workItems[id] = nil
            action()
        }

        workItems[id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    public func flush(id: String, action: @escaping () -> Void) {
        workItems.removeValue(forKey: id)?.cancel()
        action()
    }

    public func cancelAll() {
        workItems.values.forEach { $0.cancel() }
        workItems = [:]
    }
}
