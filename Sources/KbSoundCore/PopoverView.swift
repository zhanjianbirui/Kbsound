import SwiftUI

/// 菜单栏 popover 的内容。
///
/// 注意：不要在这里用 `.glassEffect()`——NSPopover 自身已是导航层材质，
/// 叠加会构成 "glass on glass"。层次靠填充色和间距表达。
public struct PopoverView: View {
    @Bindable private var state: AppState

    /// 导入失败时显示的提示，成功后清空。
    @State private var importError: String?

    /// 在模态面板期间固定住 popover。popover 是 transient，
    /// 弹 NSOpenPanel 时会失焦自动关闭，用户就看不到结果了。
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

    /// 导入不是主操作，保持中性——tint 留给选中的音效包和总开关。
    private var importButton: some View {
        Button {
            importPack()
        } label: {
            Label("导入音效包…", systemImage: "plus")
                .font(.callout)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityHint("选择一个音效包文件夹，支持 Mechvibes 格式")
    }

    private func importPack() {
        keepingOpen { runImportPanel() }
    }

    private func runImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "导入"
        panel.message = "选择音效包所在的文件夹（支持 Mechvibes 与 KbSound 格式）"
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
            "这个文件夹里没有 manifest.json 或 config.json，无法识别格式。"
        case PackImporter.ImportError.missingAudio(let file):
            "音效包缺少音频文件：\(file)"
        case PackImporter.ImportError.noKeysDefined:
            "这个音效包没有定义任何按键音。"
        case PackImporter.ImportError.unsupportedSoundPattern(let pattern):
            "不支持的音效路径格式：\(pattern)"
        default:
            "导入失败：\(error.localizedDescription)"
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
