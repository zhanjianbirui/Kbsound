/// 推断修饰键的按下/抬起方向。
///
/// `flagsChanged` 事件不带方向：按下 Shift 和松开 Shift 是同一种事件。
/// 只能自己记住哪些键当前处于按下状态。
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

    /// tap 重启后内部状态可能与现实不符，清空重来。
    public mutating func reset() {
        heldKeys.removeAll()
    }
}
