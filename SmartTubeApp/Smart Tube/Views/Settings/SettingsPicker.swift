import SwiftUI

// MARK: - SettingsPicker
//
// A settings row that opens its own page of options. On tvOS 27.2 the system `Picker` pushes an
// empty page from a `Form`, with nothing to focus. Options are written as for `Picker`: views
// marked with `.tag(_:)`.

struct SettingsPicker<Value: Hashable, Content: View, Icon: View>: View {
    private let title: Text
    @Binding private var selection: Value
    private let content: Content
    private let icon: Icon

    init(
        _ title: Text,
        selection: Binding<Value>,
        @ViewBuilder content: () -> Content,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        _selection = selection
        self.content = content()
        self.icon = icon()
    }

    var body: some View {
        NavigationLink {
            SettingsPickerOptions(title: title, selection: $selection, content: content)
        } label: {
            LabeledContent {
                Group(subviews: content) { options in
                    ForEach(options) { option in
                        if option.containerValues.hasTag(selection) {
                            option
                        }
                    }
                }
            } label: {
                HStack {
                    icon
                    title
                }
            }
        }
    }
}

extension SettingsPicker where Icon == EmptyView {
    init(
        _ titleKey: LocalizedStringKey,
        selection: Binding<Value>,
        @ViewBuilder content: () -> Content
    ) {
        self.init(Text(titleKey), selection: selection, content: content) { EmptyView() }
    }
}

// MARK: - SettingsPickerOptions

private struct SettingsPickerOptions<Value: Hashable, Content: View>: View {
    let title: Text
    @Binding var selection: Value
    let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsPageLayout {
            List {
                Group(subviews: content) { options in
                    ForEach(options) { option in
                        if let value = option.containerValues.tag(for: Value.self) {
                            Button {
                                selection = value
                                dismiss()
                            } label: {
                                HStack {
                                    option
                                    Spacer()
                                    if value == selection {
                                        Image(systemName: AppSymbol.checkmark)
                                    }
                                }
                            }
                        } else {
                            option
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

// MARK: - Previews

#if DEBUG
private struct SettingsPickerPreview: View {
    @State private var selection = 1

    var options: some View {
        ForEach(1...4, id: \.self) { Text("Option \($0)").tag($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                SettingsPicker("A setting", selection: $selection) { options }
            }
        }
    }
}

#Preview("Row") {
    SettingsPickerPreview()
}
#Preview("Options page") {
    @Previewable @State var selection = 2
    NavigationStack {
        SettingsPickerOptions(
            title: Text("A setting"),
            selection: $selection,
            content: ForEach(1...4, id: \.self) { Text("Option \($0)").tag($0) }
        )
    }
}
#endif
