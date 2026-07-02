import SwiftUI

struct SettingsPanel: View {
  @Binding var settings: ShellSettingsConfig
  @Binding var selectedSection: SettingsSection
  let closeAction: () -> Void
  @Namespace private var settingsGlassNamespace

  @ViewBuilder
  var body: some View {
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        GlassEffectContainer(spacing: KeydexSettingsLayout.glassContainerSpacing) {
          panelContent
            .keydexSheetGlassPanel(namespace: settingsGlassNamespace)
        }
      } else {
        legacyPanel
      }
    #else
      legacyPanel
    #endif
  }

  private var legacyPanel: some View {
    panelContent
      .keydexSheetGlassPanel()
  }

  private var panelContent: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
              .font(.title2.weight(.semibold))
              .accessibilityLabel("Keydex settings")
            Text(settingsSummary)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          HStack(spacing: 8) {
            SettingsStatusPill(
              title: "Keychain",
              value: settings.keychainAccess ? "On" : "Off",
              systemImage: settings.keychainAccess ? "key.fill" : "key.slash"
            )
            SettingsStatusPill(
              title: "Sources",
              value: "\(enabledSourceCount)/\(settings.scanSources.count)",
              systemImage: "checklist"
            )
            SettingsStatusPill(
              title: "Tags",
              value: "\(settings.tags.count)",
              systemImage: "tag"
            )

            SettingsCloseButton {
              closeAction()
            }
          }
          .layoutPriority(1)
        }

        Picker("Settings section", selection: $selectedSection) {
          ForEach(SettingsSection.allCases) { section in
            Text(section.title).tag(section)
          }
        }
        .pickerStyle(.segmented)
        .padding(4)
        .keydexControlGlassPanel(cornerRadius: 8)
        .accessibilityIdentifier("keydex.settings.section-picker")
        .accessibilityLabel("Settings section")
      }
      .padding(.horizontal, 24)
      .padding(.top, 20)
      .padding(.bottom, 16)
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(.separator.opacity(0.45))
          .frame(height: 1)
      }

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          switch selectedSection {
          case .permissions:
            SettingsGlassSection(
              title: "Keychain Permission",
              subtitle: keychainPermissionStatus,
              systemImage: "key.fill"
            ) {
              SettingsToggleRow(
                title: "Enable keychain access",
                subtitle: "Include Keychain references in local inventory scans",
                systemImage: "lock.open",
                isOn: $settings.keychainAccess,
                accessibilityIdentifier: "keydex.settings.keychain-access"
              )

              SettingsDivider()

              SettingsToggleRow(
                title: "Request runtime keychain prompt",
                subtitle: "Ask before a scan reads Keychain item references",
                systemImage: "hand.raised",
                isOn: $settings.requestPrompt,
                accessibilityIdentifier: "keydex.settings.request-prompt"
              )
            }

            EditableSettingsListSection(
              title: "Keychain References",
              subtitle: "\(settings.keychainReferences.count) tracked",
              systemImage: "key.fill",
              textFieldLabel: "service/account",
              addLabel: "Add keychain reference",
              removeLabel: "Remove keychain reference",
              rows: $settings.keychainReferences,
              monospace: true,
              valueFieldIdentifier: "keydex.settings.keychain-reference.value",
              draftFieldIdentifier: "keydex.settings.keychain-reference.draft",
              addButtonIdentifier: "keydex.settings.add-keychain-reference",
              removeButtonIdentifier: "keydex.settings.remove-keychain-reference"
            )

          case .appearance:
            SettingsGlassSection(
              title: "Appearance",
              subtitle: "\(settings.displayMode.title) · System light/dark",
              systemImage: "sparkles"
            ) {
              SettingsDisplayModeRow(selection: $settings.displayMode)
            }

          case .sources:
            SettingsGlassSection(
              title: "Scan Sources",
              subtitle: "\(enabledSourceCount) enabled",
              systemImage: "checklist"
            ) {
              ForEach($settings.scanSources) { $source in
                SettingsToggleRow(
                  title: source.title,
                  subtitle: source.detail,
                  systemImage: source.systemImage,
                  isOn: $source.enabled,
                  accessibilityIdentifier:
                    "keydex.settings.scan-source.\(source.accessibilitySuffix)"
                )

                if source.id != settings.scanSources.last?.id {
                  SettingsDivider()
                }
              }
            }

          case .paths:
            EditableSettingsListSection(
              title: "Scan Paths",
              subtitle: "\(settings.scanPaths.count) paths",
              systemImage: "folder",
              textFieldLabel: "Path",
              addLabel: "Add scan path",
              removeLabel: "Remove scan path",
              rows: $settings.scanPaths,
              monospace: true,
              valueFieldIdentifier: "keydex.settings.scan-path.value",
              draftFieldIdentifier: "keydex.settings.scan-path.draft",
              addButtonIdentifier: "keydex.settings.add-scan-path",
              removeButtonIdentifier: "keydex.settings.remove-scan-path"
            )

          case .tags:
            EditableTagListSection(tags: $settings.tags)

          case .rules:
            EditableSettingsListSection(
              title: "Ignored Sources",
              subtitle: "\(settings.ignoredSources.count) ignored",
              systemImage: "eye.slash",
              textFieldLabel: "Source",
              addLabel: "Add ignored source",
              removeLabel: "Remove ignored source",
              rows: $settings.ignoredSources,
              monospace: false,
              valueFieldIdentifier: "keydex.settings.ignored-source.value",
              draftFieldIdentifier: "keydex.settings.ignored-source.draft",
              addButtonIdentifier: "keydex.settings.add-ignored-source",
              removeButtonIdentifier: "keydex.settings.remove-ignored-source"
            )
            EditableSettingsListSection(
              title: "Unmanaged Sources",
              subtitle: "\(settings.unmanagedSources.count) unmanaged",
              systemImage: "tray",
              textFieldLabel: "Source",
              addLabel: "Add unmanaged source",
              removeLabel: "Remove unmanaged source",
              rows: $settings.unmanagedSources,
              monospace: false,
              valueFieldIdentifier: "keydex.settings.unmanaged-source.value",
              draftFieldIdentifier: "keydex.settings.unmanaged-source.draft",
              addButtonIdentifier: "keydex.settings.add-unmanaged-source",
              removeButtonIdentifier: "keydex.settings.remove-unmanaged-source"
            )
          }
        }
        .padding(24)
      }
    }
    .frame(width: KeydexSettingsLayout.panelWidth, height: KeydexSettingsLayout.panelHeight)
    .onExitCommand(perform: closeAction)
    .accessibilityIdentifier("keydex.settings.panel")
    .accessibilityLabel("Keydex settings")
  }

  private var enabledSourceCount: Int {
    settings.scanSources.filter(\.enabled).count
  }

  private var settingsSummary: String {
    "\(settings.displayMode.title) · \(settings.tags.count) tags · \(settings.scanPaths.count) paths · \(settings.ignoredSources.count) ignored"
  }

  private var keychainPermissionStatus: String {
    if settings.keychainAccess {
      return "Enabled for inventory scan runs"
    }

    return "Disabled for inventory scan runs"
  }
}

private struct EditableSettingsListSection: View {
  let title: String
  let subtitle: String
  let systemImage: String
  let textFieldLabel: String
  let addLabel: String
  let removeLabel: String
  @Binding var rows: [EditableSettingsRow]
  var monospace: Bool
  let valueFieldIdentifier: String
  let draftFieldIdentifier: String
  let addButtonIdentifier: String
  let removeButtonIdentifier: String
  @State private var draftValue = ""

  var body: some View {
    SettingsGlassSection(title: title, subtitle: subtitle, systemImage: systemImage) {
      ForEach($rows) { $row in
        SettingsEditableRow(
          textFieldLabel: textFieldLabel,
          removeLabel: removeLabel,
          text: $row.value,
          monospace: monospace,
          valueFieldIdentifier: valueFieldIdentifier,
          removeButtonIdentifier: removeButtonIdentifier
        ) {
          rows.removeAll { $0.id == row.id }
        }

        if row.id != rows.last?.id {
          SettingsDivider()
        }
      }

      if !rows.isEmpty {
        SettingsDivider()
      }

      HStack(alignment: .center, spacing: 10) {
        Image(systemName: "plus.circle.fill")
          .font(.body.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 24)

        TextField(textFieldLabel, text: $draftValue)
          .textFieldStyle(.plain)
          .font(monospace ? .system(.body, design: .monospaced) : .body)
          .accessibilityIdentifier(draftFieldIdentifier)
          .accessibilityLabel(textFieldLabel)

        Button {
          addDraftValue()
        } label: {
          Label(addLabel, systemImage: "plus")
        }
        .keydexGlassButton()
        .labelStyle(.iconOnly)
        .help(addLabel)
        .accessibilityLabel(addLabel)
        .accessibilityIdentifier(addButtonIdentifier)
        .disabled(trimmedDraftValue.isEmpty)
      }
      .padding(.vertical, 8)
    }
  }

  private var trimmedDraftValue: String {
    draftValue.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func addDraftValue() {
    rows.append(EditableSettingsRow(trimmedDraftValue))
    draftValue = ""
  }
}

private struct EditableTagListSection: View {
  @Binding var tags: [CredentialTagRow]
  @State private var draftName = ""
  @State private var draftAssignments = ""
  @State private var draftColor = CredentialTagColor.accent

  var body: some View {
    SettingsGlassSection(
      title: "Credential Tags",
      subtitle: "\(tags.count) user-managed tags",
      systemImage: "tag.fill"
    ) {
      ForEach($tags) { $tag in
        SettingsTagEditableRow(tag: $tag) {
          tags.removeAll { $0.id == tag.id }
        }

        if tag.id != tags.last?.id {
          SettingsDivider()
        }
      }

      if !tags.isEmpty {
        SettingsDivider()
      }

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .center, spacing: 10) {
          Image(systemName: "plus.circle.fill")
            .font(.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 24)

          TextField("Tag name", text: $draftName)
            .textFieldStyle(.plain)
            .font(.body)
            .accessibilityIdentifier("keydex.settings.tag.draft-name")
            .accessibilityLabel("New tag name")

          Picker("Tag color", selection: $draftColor) {
            ForEach(CredentialTagColor.allCases) { color in
              Text(color.title).tag(color)
            }
          }
          .labelsHidden()
          .frame(width: 118)
          .accessibilityIdentifier("keydex.settings.tag.draft-color")
          .accessibilityLabel("New tag color")

          Button {
            addDraftTag()
          } label: {
            Label("Add tag", systemImage: "plus")
          }
          .keydexGlassButton()
          .labelStyle(.iconOnly)
          .help("Add tag")
          .accessibilityLabel("Add tag")
          .accessibilityIdentifier("keydex.settings.add-tag")
          .disabled(trimmedDraftName.isEmpty)
        }

        HStack(spacing: 10) {
          Color.clear
            .frame(width: 24)
            .accessibilityHidden(true)

          TextField("service|account, service|account", text: $draftAssignments)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .accessibilityIdentifier("keydex.settings.tag.draft-assignments")
            .accessibilityLabel("New tag credential assignments")
        }
      }
      .padding(.vertical, 8)
    }
  }

  private var trimmedDraftName: String {
    draftName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedDraftAssignments: String {
    draftAssignments.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func addDraftTag() {
    tags.append(
      CredentialTagRow(
        name: trimmedDraftName,
        assignments: trimmedDraftAssignments,
        color: draftColor
      )
    )
    draftName = ""
    draftAssignments = ""
    draftColor = .accent
  }
}

private struct SettingsTagEditableRow: View {
  @Binding var tag: CredentialTagRow
  let removeAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center, spacing: 10) {
        Image(systemName: "tag.fill")
          .font(.body.weight(.medium))
          .foregroundStyle(tag.color.tint)
          .frame(width: 24)

        TextField("Tag name", text: $tag.name)
          .textFieldStyle(.plain)
          .font(.body)
          .accessibilityIdentifier("keydex.settings.tag.name")
          .accessibilityLabel("Tag name")

        Picker("Tag color", selection: $tag.color) {
          ForEach(CredentialTagColor.allCases) { color in
            Text(color.title).tag(color)
          }
        }
        .labelsHidden()
        .frame(width: 118)
        .accessibilityIdentifier("keydex.settings.tag.color")
        .accessibilityLabel("Tag color")

        Button {
          removeAction()
        } label: {
          Label("Remove tag", systemImage: "minus")
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .help("Remove tag")
        .accessibilityLabel("Remove tag")
        .accessibilityIdentifier("keydex.settings.remove-tag")
      }

      HStack(spacing: 10) {
        Color.clear
          .frame(width: 24)
          .accessibilityHidden(true)

        TextField("service|account assignments", text: $tag.assignments)
          .textFieldStyle(.plain)
          .font(.system(.body, design: .monospaced))
          .accessibilityIdentifier("keydex.settings.tag.assignments")
          .accessibilityLabel("Tag credential assignments")
      }
    }
    .padding(.vertical, 8)
  }
}

private struct SettingsDisplayModeRow: View {
  @Binding var selection: InventoryDisplayMode

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: "rectangle.grid.2x2")
        .font(.body.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 3) {
        Text("Display mode")
          .font(.body)
        Text("Choose dense rows or scannable cards without changing graph truth")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 12)

      Picker("Display mode", selection: $selection) {
        ForEach(InventoryDisplayMode.allCases) { mode in
          Label(mode.title, systemImage: mode.systemImage).tag(mode)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(width: 180)
      .accessibilityIdentifier("keydex.settings.display-mode")
      .accessibilityLabel("Display mode")
    }
    .padding(.vertical, 8)
  }
}

private struct SettingsCloseButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        Image(systemName: "xmark.circle.fill")
          .font(.title3.weight(.semibold))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(.secondary)

        Text("Close settings")
          .frame(width: 0, height: 0)
          .opacity(0.01)
      }
      .frame(width: 32, height: 32)
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .keyboardShortcut(.escape, modifiers: [])
    .help("Close settings")
    .accessibilityIdentifier("keydex.settings.close")
    .accessibilityLabel("Close settings")
  }
}

private struct SettingsStatusPill: View {
  let title: String
  let value: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.caption.weight(.semibold))
      Text(title)
        .lineLimit(1)
      Text(value)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .font(.caption.weight(.medium))
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .fixedSize(horizontal: true, vertical: false)
    .keydexCapsuleGlass()
  }
}

private struct SettingsGlassSection<Content: View>: View {
  let title: String
  let subtitle: String
  let systemImage: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Image(systemName: systemImage)
          .font(.body.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.headline)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }

      VStack(spacing: 0) {
        content
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .keydexGroupedRowsSurface()
    }
  }
}

private struct SettingsToggleRow: View {
  let title: String
  let subtitle: String
  let systemImage: String
  @Binding var isOn: Bool
  let accessibilityIdentifier: String

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: systemImage)
          .font(.body.weight(.medium))
          .foregroundStyle(.secondary)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.body)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Toggle(title, isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .frame(width: 54, alignment: .trailing)
    }
    .padding(.vertical, 8)
    .help(subtitle)
    .accessibilityIdentifier(accessibilityIdentifier)
  }
}

private struct SettingsEditableRow: View {
  let textFieldLabel: String
  let removeLabel: String
  @Binding var text: String
  var monospace: Bool
  let valueFieldIdentifier: String
  let removeButtonIdentifier: String
  let removeAction: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: monospace ? "folder" : "line.3.horizontal.decrease.circle")
        .font(.body.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(width: 24)

      TextField(textFieldLabel, text: $text)
        .textFieldStyle(.plain)
        .font(monospace ? .system(.body, design: .monospaced) : .body)
        .accessibilityIdentifier(valueFieldIdentifier)
        .accessibilityLabel(textFieldLabel)

      Button {
        removeAction()
      } label: {
        Label(removeLabel, systemImage: "minus")
      }
      .buttonStyle(.borderless)
      .labelStyle(.iconOnly)
      .help(removeLabel)
      .accessibilityLabel(removeLabel)
      .accessibilityIdentifier(removeButtonIdentifier)
    }
    .padding(.vertical, 8)
  }
}

private struct SettingsDivider: View {
  var body: some View {
    Rectangle()
      .fill(.separator.opacity(0.55))
      .frame(height: 1)
      .padding(.leading, 34)
  }
}
