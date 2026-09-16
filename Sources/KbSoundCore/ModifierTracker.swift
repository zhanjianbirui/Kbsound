/// Infers whether a modifier key went down or came up.
///
/// `flagsChanged` events carry no direction: pressing Shift and releasing it look
/// identical. The only option is to remember which keys are currently held.
public struct ModifierTracker {
    private var heldKeys: Set<Int> = []

    public init() {}

    public mutating func phase(forKeyCode keyCode: Int) -> KeyPhase {
        if heldKeys.contains(keyCode) {
            heldKeys.remove(keyCode)
            return .up
        }
        heldKeys.insert(keyCode)
        return .down
    }

    /// After the tap restarts the tracked state may no longer match reality; start over.
    public mutating func reset() {
        heldKeys.removeAll()
    }
}
