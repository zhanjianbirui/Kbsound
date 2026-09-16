import Foundation

/// Resolves a UI string against the `KbSoundCore` resource bundle.
///
/// SwiftUI's `Text("some key")` looks the key up in `Bundle.main`, but the
/// strings files ship inside this package's own resource bundle. Resolving
/// eagerly keeps every call site — views, open panels, accessibility labels,
/// error messages — on the same lookup path.
func loc(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
