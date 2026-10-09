import SwiftUI
import AppKit

struct QueryInspectorView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject var l10n = LocalizationManager.shared
    
    @State private var selectedFilter: QueryFilterTab = .all
    @State private var searchText: String = ""
    @State private var selectedQueryId: String? = nil
    
    var body: some View {
        VStack(spacing: 14) {
            // MARK: - Header & Controls
            headerSection
            
            // MARK: - Filter Bar & Stats
            filterBarSection
            
            // MARK: - Live Stream Table
            tableSection
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(manager.isStreamFrozen ? Theme.statusOrange : Theme.statusGreen)
                        .frame(width: 8, height: 8)
                    
                    Text(tr("Инспектор DNS-запросов", "Live DNS Query Inspector", "DNS-сурамдардын инспектору"))
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(streamBadgeText)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(streamBadgeColor.opacity(0.18))
                        .foregroundColor(streamBadgeColor)
                        .clipShape(Capsule())
                }
                
                Text(streamSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                // Freeze / Resume Stream
                Button(action: { manager.toggleStreamFreeze() }) {
                    HStack(spacing: 6) {
                        Image(systemName: manager.isStreamFrozen ? "play.fill" : "pause.fill")
                            .font(.system(size: 11))
                        Text(manager.isStreamFrozen ?
                             (tr("Продолжить", "Resume", "Улантуу")) :
                             (tr("Пауза", "Pause", "Тыным")))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(tr("Приостановить / продолжить поток запросов", "Pause / resume the query stream", "Сурамдар агымын тындыруу / улантуу"))
                
                // Clear
                Button(action: { manager.clearQueryLog() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text(tr("Очистить", "Clear", "Тазалоо"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(tr("Очистить текущую историю запросов", "Clear the current query history", "Учурдагы сурамдар тарыхын тазалоо"))
                
                // Export JSON
                Button(action: exportQueries) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text("JSON")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.15))
                    .foregroundColor(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(tr("Экспортировать запросы в файл JSON", "Export queries to a JSON file", "Сурамдарды JSON файлына экспорттоо"))
            }
        }
    }
    
    // MARK: - Filter Bar & Stats
    private var filterBarSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Search Input
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    TextField(tr("Поиск по домену...", "Search domain...", "Домен боюнча издөө..."), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tr("Очистить поле", "Clear the field", "Талааны тазалоо"))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                
                // Filter Segmented Buttons
                HStack(spacing: 4) {
                    ForEach(QueryFilterTab.allCases) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                selectedFilter = tab
                            }
                        }) {
                            Text(tab.title)
                                .font(.system(size: 11, weight: selectedFilter == tab ? .bold : .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(selectedFilter == tab ? Color(NSColor.controlAccentColor).opacity(0.2) : Color.clear)
                                )
                                .foregroundColor(selectedFilter == tab ? Theme.accent : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            // Mini Analytics Pills
            HStack(spacing: 8) {
                // Раньше здесь стояли несопоставимые величины: слева — число
                // строк после фильтра, справа — накопительный счётчик за сессию.
                // Выглядело как «31 запрос, из них заблокировано 252».
                QueryStatPill(
                    icon: "line.3.horizontal.decrease",
                    label: tr("Показано", "Shown", "Көрсөтүлдү"),
                    value: "\(filteredQueries.count) / \(manager.queries.count)",
                    color: Theme.accent
                )
                
                QueryStatPill(
                    icon: "list.bullet",
                    label: tr("Всего за сессию", "Session total", "Сессиядагы бардыгы"),
                    value: "\(manager.analytics.totalQueries)",
                    color: Theme.statusBlue
                )
                
                QueryStatPill(
                    icon: "shield.fill",
                    label: tr("Заблокировано", "Blocked", "Бөгөттөлдү"),
                    value: "\(manager.analytics.blockedQueries) (\(String(format: "%.1f", manager.analytics.blockRatioPct))%)",
                    color: Theme.statusRed
                )
                
                QueryStatPill(
                    icon: "arrow.down.circle",
                    label: tr("Экономия (оценка)", "Saved (est.)", "Үнөмдөө (болжол)"),
                    value: String(format: tr("%.1f МБ", "%.1f MB", "%.1f МБ"), manager.analytics.dataSavedMB),
                    color: Theme.statusGreen
                )
                
                Spacer()
            }
        }
    }
    
    // MARK: - Table Section
    private var tableSection: some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 10) {
                Text(tr("ВРЕМЯ", "TIME", "УБАКЫТ"))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 62, alignment: .leading)
                
                Text(tr("СТАТУС", "STATUS", "АБАЛ"))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 72, alignment: .leading)
                
                Text(tr("ДОМЕН И КАТЕГОРИЯ", "DOMAIN & CATEGORY", "ДОМЕН ЖАНА КАТЕГОРИЯ"))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(tr("ТИП", "TYPE", "ТҮРҮ"))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .leading)
                
                Text(tr("ПИНГ", "PING", "ПИНГ"))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 48, alignment: .trailing)
                
                Text(tr("ДЕЙСТВИЕ", "ACTION", "АРАКЕТ"))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.controlBackground.opacity(0.7))
            
            Divider().opacity(0.3)
            
            // List of Queries
            if filteredQueries.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(tr("Нет запросов, соответствующих фильтру", "No queries matching filter", "Чыпкага туура келген сурамдар жок"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredQueries) { query in
                            QueryLogRow(
                                query: query,
                                isSelected: selectedQueryId == query.id,
                                onSelect: {
                                    if selectedQueryId == query.id {
                                        selectedQueryId = nil
                                    } else {
                                        selectedQueryId = query.id
                                    }
                                },
                                onBlacklist: { manager.addDomainToBlacklistFromInspector(query.domain) },
                                onWhitelist: { manager.addDomainToWhitelistFromInspector(query.domain) }
                            )
                        }
                    }
                }
            }
            
            if let selectedQuery = filteredQueries.first(where: { $0.id == selectedQueryId }) {
                Divider().opacity(0.3)
                QueryDetailCard(
                    query: selectedQuery,
                    isRu: isRu,
                    onClose: { selectedQueryId = nil },
                    onWhitelist: { manager.addDomainToWhitelistFromInspector(selectedQuery.domain) },
                    onBlacklist: { manager.addDomainToBlacklistFromInspector(selectedQuery.domain) }
                )
            }
        }
        .background(Theme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    private var isRu: Bool { l10n.currentLanguage == .ru }

    private var streamBadgeText: String {
        if manager.isStreamFrozen { return tr("ПАУЗА", "PAUSED", "ТЫНЫМ") }
        return manager.isQueryStreamSimulated ? tr("ДЕМО", "DEMO", "ДЕМО") : "LIVE"
    }

    private var streamBadgeColor: Color {
        if manager.isStreamFrozen { return Theme.statusOrange }
        return manager.isQueryStreamSimulated ? Theme.statusPurple : Theme.statusGreen
    }

    private var streamSubtitle: String {
        if manager.isQueryStreamSimulated {
            return tr("Показан демонстрационный поток. Настоящий журнал запросов ведёт только локальный dnsmasq — включите профиль «Локальный dnsmasq» в разделе «Профили DNS».", "Showing a demo stream. Only the local dnsmasq resolver keeps a real query log — enable the “Local dnsmasq” profile under DNS Profiles.", "Демонстрациялык агым көрсөтүлүүдө. Чыныгы сурамдар журналын локалдык dnsmasq гана жүргүзөт — «DNS профилдери» бөлүмүндө «Локалдык dnsmasq» профилин күйгүзүңүз.")
        }
        return tr("Реальные запросы из журнала локального dnsmasq.", "Live queries read from the local dnsmasq log.", "Локалдык dnsmasq журналындагы чыныгы сурамдар.")
    }

    private var filteredQueries: [DNSQueryLogItem] {
        let text = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        
        return manager.queries.filter { q in
            // Filter by search text
            if !text.isEmpty && !q.domain.lowercased().contains(text) {
                return false
            }
            // Filter by Tab
            switch selectedFilter {
            case .all: return true
            case .blocked: return q.isBlocked
            case .allowed: return !q.isBlocked
            case .ads: return q.category == .ad
            case .trackers: return q.category == .tracker || q.category == .telemetry
            }
        }
    }
    
    private func exportQueries() {
        let jsonStr = manager.exportQueriesJSON()
        let savePanel = NSSavePanel()
        savePanel.title = tr("Экспорт лога DNS-запросов", "Export DNS query log", "DNS-сурамдардын логун экспорттоо")
        savePanel.nameFieldStringValue = "cerberus_dns_queries_\(Int(Date().timeIntervalSince1970)).json"
        savePanel.allowedContentTypes = [.json]
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                try jsonStr.write(to: url, atomically: true, encoding: .utf8)
                manager.showBanner((tr("Лог экспортирован в ", "Log exported to ", "Лог экспорттолду: ")) + url.lastPathComponent)
            } catch {
                manager.showBanner((tr("Не удалось сохранить: ", "Save failed: ", "Сактоо мүмкүн болгон жок: ")) + error.localizedDescription)
                manager.appendLog(tr("Экспорт лога: \(error.localizedDescription)", "Log export: \(error.localizedDescription)", "Логду экспорттоо: \(error.localizedDescription)"), isError: true)
            }
        }
    }
}

// MARK: - Query Stat Pill
struct QueryStatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Query Log Row
struct QueryLogRow: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    private var isRu: Bool { l10n.currentLanguage == .ru }

    let query: DNSQueryLogItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onBlacklist: () -> Void
    let onWhitelist: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Timestamp
            Text(formattedTime(query.timestamp))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 62, alignment: .leading)
            
            // Status Badge
            HStack(spacing: 4) {
                Image(systemName: query.isBlocked ? "shield.fill" : (query.status == .cached ? "bolt.horizontal.fill" : "checkmark.circle.fill"))
                    .font(.system(size: 9, weight: .bold))
                
                Text(query.status == .cached
                     ? (tr("Кэш", "Cache", "Кэш"))
                     : (query.isBlocked ? (tr("Блок", "Block", "Бөгөт")) : "OK"))
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundColor(query.isBlocked ? Theme.statusRed : Theme.statusGreen)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background((query.isBlocked ? Theme.statusRed : Theme.statusGreen).opacity(0.12))
            .clipShape(Capsule())
            .frame(width: 72, alignment: .leading)
            
            // Domain & Category
            HStack(spacing: 8) {
                Text(query.domain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(query.category.title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(query.category.color.opacity(0.12))
                    .foregroundColor(query.category.color)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Query Type
            Text(simplifiedQueryType)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)
            
            // Ping / Latency
            Text(tr("\(query.latencyMs) мс", "\(query.latencyMs) ms", "\(query.latencyMs) мс"))
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundColor(query.latencyMs < 10 ? Theme.statusGreen : .secondary)
                .frame(width: 48, alignment: .trailing)
            
            // Quick Action Button
            HStack {
                if query.isBlocked {
                    Button(action: onWhitelist) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Theme.statusGreen)
                            .frame(width: 22, height: 22)
                            .background(Theme.statusGreen.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(tr("Разрешить домен (в белый список)", "Allow domain (add to whitelist)", "Доменге уруксат берүү (ак тизмеге)"))
                    .accessibilityLabel(tr("Разрешить \(query.domain)", "Allow \(query.domain)", "Уруксат: \(query.domain)"))
                } else {
                    Button(action: onBlacklist) {
                        Image(systemName: "nosign")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Theme.statusRed)
                            .frame(width: 22, height: 22)
                            .background(Theme.statusRed.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(tr("Заблокировать домен (в чёрный список)", "Block domain (add to blacklist)", "Доменди бөгөттөө (кара тизмеге)"))
                    .accessibilityLabel(tr("Заблокировать \(query.domain)", "Block \(query.domain)", "\(query.domain) доменин бөгөттөө"))
                }
            }
            .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.12) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
        )
        .onHover { h in isHovered = h }
        .onTapGesture { onSelect() }
    }
    
    private var simplifiedQueryType: String {
        let first = query.queryType.components(separatedBy: " ").first ?? "A"
        return first.isEmpty ? "A" : first
    }
    
    /// Один формат на всё приложение. Создание `DateFormatter` заметно дороже
    /// форматирования, а здесь он создавался заново для каждой строки таблицы
    /// на каждой перерисовке.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private func formattedTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}

// MARK: - Query Detail Card Component
struct QueryDetailCard: View {
    let query: DNSQueryLogItem
    let isRu: Bool
    let onClose: () -> Void
    let onWhitelist: () -> Void
    let onBlacklist: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: query.isBlocked ? "nosign" : "checkmark.shield.fill")
                    .foregroundColor(query.isBlocked ? Theme.statusRed : Theme.statusGreen)
                    .font(.system(size: 14, weight: .bold))
                
                Text(query.domain)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(query.domain, forType: .string)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text(tr("Копировать", "Copy", "Көчүрүү"))
                    }
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                
                if query.isBlocked {
                    Button(action: onWhitelist) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text(tr("В белый список", "Whitelist", "Ак тизмеге"))
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(Theme.statusGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.statusGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onBlacklist) {
                        HStack(spacing: 4) {
                            Image(systemName: "nosign")
                            Text(tr("Заблокировать", "Blacklist", "Бөгөттөө"))
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(Theme.statusRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.statusRed.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Закрыть инспектор", "Close inspector", "Инспекторду жабуу"))
            }
            
            HStack(spacing: 16) {
                detailField(title: tr("Категория", "Category", "Категория"), value: query.category.title)
                detailField(title: tr("Клиент", "Client IP", "Клиент"), value: query.clientIp.isEmpty ? "127.0.0.1" : query.clientIp)
                detailField(title: tr("Тип", "Query Type", "Түрү"), value: query.queryType)
                detailField(title: tr("Задержка", "Latency", "Кечигүү"), value: "\(query.latencyMs) ms")
                detailField(title: tr("Статус", "Status", "Абалы"), value: query.isBlocked ? (tr("Заблокирован", "Blocked", "Бөгөттөлдү")) : (tr("Разрешён", "Allowed", "Уруксат берилди")))
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
    }
    
    private func detailField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}
