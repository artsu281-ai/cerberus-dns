import SwiftUI
import AppKit

struct CommandPaletteView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject private var themeMgr = ThemeManager.shared
    @Binding var isPresented: Bool
    
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var cachedItems: [CommandPaletteItem] = []
    @State private var keyMonitor: Any? = nil
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.accent)
                
                TextField(tr("Быстрый поиск команд, профилей или действий...", "Search commands, profiles or actions...", "Буйруктарды, профилдерди же аракеттерди тез издөө..."), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFocused)
                    .onChange(of: query) { _ in
                        selectedIndex = 0
                    }
                
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Очистить поле", "Clear the field", "Талааны тазалоо"))
                }
                
                Text("ESC")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Theme.controlBackground)
            
            Divider().opacity(0.3)
            
            // Filtered Items List (Optimized LazyVStack with Keyboard Auto-Scroll)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        let items = filteredItems
                        if items.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text(tr("Ничего не найдено", "No matches", "Эч нерсе табылган жок"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                        } else {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    onSelect: {
                                        item.action()
                                        isPresented = false
                                    }
                                )
                                .id(item.id)
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 290)
                .onChange(of: selectedIndex) { newIdx in
                    let items = filteredItems
                    if newIdx >= 0 && newIdx < items.count {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(items[newIdx].id, anchor: .center)
                        }
                    }
                }
            }
            
            Divider().opacity(0.3)
            
            // Footer Hints
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Text("↑↓").font(.system(size: 10, weight: .bold, design: .monospaced))
                    Text(tr("Навигация", "Navigate", "Навигация")).font(.system(size: 10)).foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Text("↵").font(.system(size: 10, weight: .bold, design: .monospaced))
                    Text(tr("Выбрать", "Select", "Тандоо")).font(.system(size: 10)).foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(tr("Палитра команд • Cerberus DNS", "Command palette • Cerberus DNS", "Буйруктар палитрасы • Cerberus DNS"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Theme.controlBackground)
        }
        .frame(width: 520)
        .background(Theme.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
        .preferredColorScheme(themeMgr.appearance.colorScheme)
        .animation(.easeInOut(duration: 0.25), value: themeMgr.appearance)
        .onAppear {
            cachedItems = manager.getCommandPaletteItems()
            isSearchFocused = true
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event: NSEvent) -> NSEvent? in
                let items = self.filteredItems
                guard !items.isEmpty else {
                    if event.keyCode == 53 { // ESC
                        isPresented = false
                        return nil
                    }
                    return event
                }
                switch event.keyCode {
                case 126: // Up Arrow
                    if selectedIndex > 0 {
                        selectedIndex -= 1
                    }
                    return nil
                case 125: // Down Arrow
                    if selectedIndex < items.count - 1 {
                        selectedIndex += 1
                    }
                    return nil
                case 36: // Enter / Return
                    if selectedIndex >= 0 && selectedIndex < items.count {
                        let chosen = items[selectedIndex]
                        chosen.action()
                        isPresented = false
                    }
                    return nil
                case 53: // Escape
                    isPresented = false
                    return nil
                default:
                    return event
                }
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }
    
    private var filteredItems: [CommandPaletteItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            return cachedItems
        }
        return cachedItems.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.subtitle.localizedCaseInsensitiveContains(q) ||
            $0.category.localizedCaseInsensitiveContains(q)
        }
    }
}

// MARK: - Row Component
struct CommandPaletteRow: View {
    let item: CommandPaletteItem
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 11) {
                // Colored Glass Tile (Never Generic/Stock)
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(item.iconColor.opacity(isSelected ? 0.35 : (isHovered ? 0.22 : 0.14)))
                        .frame(width: 30, height: 30)
                    
                    if let code = item.countryCode {
                        CustomCountryFlag(code: code, width: 20, height: 14)
                    } else {
                        Image(systemName: item.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? Theme.onAccent : item.iconColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(isSelected ? Theme.onAccent : .primary)
                        .lineLimit(1)
                    
                    Text(item.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundColor(isSelected ? Theme.onAccent.opacity(0.82) : .secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 6)
                
                // Semantic Category Pill
                Text(item.category)
                    .font(.system(size: 9.5, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(isSelected ? Theme.onAccent.opacity(0.22) : item.iconColor.opacity(0.12))
                    .foregroundColor(isSelected ? Theme.onAccent : item.iconColor)
                    .clipShape(Capsule())
                
                if let sc = item.shortcut {
                    Text(sc)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(isSelected ? Theme.onAccent.opacity(0.25) : Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .foregroundColor(isSelected ? Theme.onAccent : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Theme.accent : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }
}
