import SwiftUI

/// 菜单栏 popover 的内容。
///
/// 注意：不要在这里用 `.glassEffect()`——NSPopover 自身已是导航层材质，
/// 叠加会构成 "glass on glass"。层次靠填充色和间距表达。
public struct PopoverView: View {
    @Bindable private var state: AppState

    public init(state: AppState) {
        self._state = Bindable(state)
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
                Label("需要辅助功能权限", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.yellow.opacity(0.15), in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开系统设置授予辅助功能权限")
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
        Toggle("键盘音效", isOn: $state.isEnabled)
            .toggleStyle(.switch)
            .font(.headline)
    }

    private var volumeSlider: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.secondary)
            Slider(value: $state.volume, in: 0...1)
                .accessibilityLabel("音量")
            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.secondary)
        }
        .imageScale(.small)
        .disabled(!state.isEnabled)
    }

    private var packList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("音效包")
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
            Toggle("开机自启", isOn: $state.isLoginItemEnabled)
                .toggleStyle(.switch)
                .font(.callout)

            Button("退出 KbSound") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
