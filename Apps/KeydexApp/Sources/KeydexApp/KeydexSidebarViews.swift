import SwiftUI

struct KeydexRailFooter<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    ZStack(alignment: .center) {
      KeydexRailLaneBackground()

      railContent
    }
    .frame(height: KeydexRailLayout.footerLaneHeight)
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var railContent: some View {
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        GlassEffectContainer(spacing: KeydexRailLayout.glassContainerSpacing) {
          paddedContent
        }
      } else {
        paddedContent
      }
    #else
      paddedContent
    #endif
  }

  private var paddedContent: some View {
    content
      .padding(.horizontal, KeydexRailLayout.horizontalMargin)
      .padding(.top, KeydexRailLayout.footerTopPadding)
      .padding(.bottom, KeydexRailLayout.footerBottomPadding)
      .frame(maxWidth: .infinity)
  }
}

struct KeydexRailLaneBackground: View {
  var body: some View {
    Color.clear
      .overlay(alignment: .top) {
        Rectangle()
          .fill(.separator.opacity(KeydexRailLayout.footerSeparatorAlpha))
          .frame(height: 1)
      }
  }
}

struct MusicToolbarCluster: View {
  @Binding var inventoryMode: InventoryMode
  @Binding var displayMode: InventoryDisplayMode

  var body: some View {
    HStack(spacing: 10) {
      Picker("Inventory source", selection: $inventoryMode) {
        ForEach(InventoryMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 216)
      .help("Switch local, sample, or empty inventory")
      .accessibilityIdentifier("keydex.toolbar.inventory-mode")
      .accessibilityLabel("Inventory source")

      Divider()
        .frame(height: 22)

      Picker("Display mode", selection: $displayMode) {
        ForEach(InventoryDisplayMode.allCases) { mode in
          Label(mode.title, systemImage: mode.systemImage).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 164)
      .help("Switch between list and card inventory views")
      .accessibilityIdentifier("keydex.toolbar.display-mode")
      .accessibilityLabel("Display mode")
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .keydexControlGlassPanel(cornerRadius: 18)
    .accessibilityIdentifier("keydex.toolbar.mode-cluster")
    .accessibilityLabel("Inventory and display controls")
  }
}

struct MusicSidebarView: View {
  let items: [SidebarSelection]
  @Binding var selectedSidebar: SidebarSelection
  @Binding var searchText: String

  private var inventoryItems: [SidebarSelection] {
    [.all, .state(.missingKeychainItem), .state(.plaintextFallback)]
  }

  private var libraryItems: [SidebarSelection] {
    [
      .state(.registered),
      .state(.orphan),
      .state(.expiring),
      .state(.expired),
      .state(.duplicate),
    ]
  }

  private var serviceItems: [SidebarSelection] {
    items.compactMap { item in
      if case .service = item {
        return item
      }

      return nil
    }
  }

  private var tagItems: [SidebarSelection] {
    items.compactMap { item in
      if case .tag = item {
        return item
      }

      return nil
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: KeydexSidebarLayout.sectionSpacing) {
        MusicSearchField(searchText: $searchText)
          .padding(.horizontal, 4)
          .padding(.top, KeydexSidebarLayout.searchTopPadding)

        MusicSidebarSection(title: nil) {
          ForEach(inventoryItems, id: \.self) { item in
            MusicSidebarRow(
              item: item,
              selected: selectedSidebar == item
            ) {
              selectedSidebar = item
            }
          }
        }

        MusicSidebarSection(title: "Library") {
          ForEach(libraryItems, id: \.self) { item in
            MusicSidebarRow(
              item: item,
              selected: selectedSidebar == item
            ) {
              selectedSidebar = item
            }
          }
        }

        if !tagItems.isEmpty {
          MusicSidebarSection(title: "Tags") {
            ForEach(tagItems, id: \.self) { item in
              MusicSidebarRow(
                item: item,
                selected: selectedSidebar == item
              ) {
                selectedSidebar = item
              }
            }
          }
        }

        MusicSidebarSection(title: "Services") {
          ForEach(serviceItems, id: \.self) { item in
            MusicSidebarRow(
              item: item,
              selected: selectedSidebar == item
            ) {
              selectedSidebar = item
            }
          }
        }
      }
      .padding(.horizontal, KeydexSidebarLayout.contentHorizontalPadding)
      .padding(.bottom, KeydexSidebarLayout.contentBottomPadding)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .scrollContentBackground(.hidden)
    .keydexSidebarGlass()
    .accessibilityIdentifier("keydex.sidebar.scopes")
    .accessibilityLabel("Credential scopes")
    .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
  }
}

struct MusicSearchField: View {
  @Binding var searchText: String

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass")
        .font(.body)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      TextField("Search", text: $searchText)
        .textFieldStyle(.plain)
        .font(.body)
        .accessibilityLabel("Search credentials")

      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.body)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Clear search")
        .accessibilityLabel("Clear search")
      }
    }
    .keydexSidebarSearchRow()
    .accessibilityIdentifier("keydex.sidebar.search")
  }
}

struct MusicSidebarSection<Content: View>: View {
  let title: String?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: KeydexSidebarLayout.titleSpacing) {
      if let title {
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 4)
      }

      VStack(alignment: .leading, spacing: KeydexSidebarLayout.rowSpacing) {
        content
      }
    }
  }
}

struct MusicSidebarRow: View {
  let item: SidebarSelection
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(item.title, systemImage: item.systemImage)
        .font(.body.weight(selected ? .semibold : .regular))
        .foregroundStyle(selected ? Color.accentColor : .primary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KeydexSidebarLayout.rowHorizontalPadding)
        .frame(height: KeydexSidebarLayout.rowHeight)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.plain)
    .help(item.title)
  }

  @ViewBuilder private var rowBackground: some View {
    if selected {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(KeydexGlassTone.sidebarSelectionFill)
    }
  }
}
