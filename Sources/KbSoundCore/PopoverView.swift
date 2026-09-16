import SwiftUI

/// Contents of the menu bar popover.
///
/// Note: do not use `.glassEffect()` here — an NSPopover is already a navigation-layer
/// material, and stacking would make it "glass on glass". Hierarchy is carried by fill
/// colors and spacing instead.
public struct PopoverView: View {
    @Bindable private var state: AppState

    /// Message shown when an import fails; cleared on success.
    @State private var importError: String?

    /// Pins the popover open for the duration of a modal panel. The popover is
    /// transient, so presenting an NSOpenPanel makes it lose focus and close itself,
    /// leaving the user unable to see the result.
    private let keepingOpen: (() -> Void) -> Void

    public init(state: AppState, keepingOpen: @escaping (() -> Void) -> Void = { $0() }) {
        self._state = Bindable(state)
        self.keepingOpen = keepingOpen
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusBanner
            enableToggle
            volumeSlider
            Divider()
            packList
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 260)
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch state.status {
        case .ok:
            EmptyView()
        case .needsAccessibility:
            Button {
                state.requestAccessibility()
            } label: {
                Label(loc("Accessibility permission required"),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.yellow.opacity(0.15), in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityHint(loc("Opens System Settings so you can grant Accessibility permission"))
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.red.opacity(0.12), in: .rect(cornerRadius: 8))
        }
    }

    private var enableToggle: some View {
        Toggle(loc("Keyboard sounds"), isOn: $state.isEnabled)
            .toggleStyle(.switch)
            .font(.headline)
    }

    private var volumeSlider: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.secondary)
            Slider(value: $state.volume, in: 0...1)
                .accessibilityLabel(loc("Volume"))
            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.secondary)
        }
        .imageScale(.small)
        .disabled(!state.isEnabled)
    }

    private var packList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loc("Sound packs"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(state.packs) { pack in
                        packRow(pack)
                    }
                }
            }
            .frame(maxHeight: 240)

            if state.canImportPacks {
                importButton
            }
            if let importError {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Importing is not the primary action, so it stays neutral — tint belongs to the
    /// selected pack and the main switch.
    private var importButton: some View {
        Button {
            importPack()
        } label: {
            Label(loc("Import sound pack…"), systemImage: "plus")
                .font(.callout)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityHint(loc("Pick a sound pack folder; Mechvibes packs are supported"))
    }

    private func importPack() {
        keepingOpen { runImportPanel() }
    }

    private func runImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = loc("Import")
        panel.message = loc("Choose the folder that holds the sound pack (Mechvibes and KbSound formats)")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try state.importPack(from: url)
            importError = nil
        } catch {
            importError = message(for: error)
        }
    }

    private func message(for error: any Error) -> String {
        switch error {
        case PackImporter.ImportError.unrecognizedFormat:
            loc("This folder has no manifest.json or config.json, so its format cannot be recognized.")
        case PackImporter.ImportError.missingAudio(let file):
            loc("The sound pack is missing an audio file: \(file)")
        case PackImporter.ImportError.noKeysDefined:
            loc("This sound pack does not define any key sounds.")
        case PackImporter.ImportError.unsupportedSoundPattern(let pattern):
            loc("Unsupported sound path pattern: \(pattern)")
        default:
            loc("Import failed: \(error.localizedDescription)")
        }
    }

    private func packRow(_ pack: PackRef) -> some View {
        let isSelected = pack.id == state.selectedPackID
        return Button {
            state.selectedPackID = pack.id
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .opacity(isSelected ? 1 : 0)
                    .foregroundStyle(.tint)
                Text(pack.name)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .font(.callout)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .contentShape(.rect)
            .background(isSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear),
                        in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pack.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(loc("Launch at login"), isOn: $state.isLoginItemEnabled)
                .toggleStyle(.switch)
                .font(.callout)

            Button(loc("Quit KbSound")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
