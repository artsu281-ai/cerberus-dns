import SwiftUI
import AppKit

struct ToolsView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var showUninstallAlert = false
    @State private var logSearch: String = ""
    @State private var autoScroll = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Инструменты и Системный журнал", "Tools & System Console", "Куралдар жана системалык журнал"))
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                    
                    Text(tr("Служебные утилиты для оптимизации сетевого стека macOS, сброса кэша и аудита событий.", "System utilities for macOS network stack optimization, cache flushing, and live logging.", "macOS тармак стегин оптималдаштыруу, кэшти тазалоо жана окуяларды аудиттөө үчүн кызматтык утилиталар."))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // System Utilities Grid
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Системные утилиты", "System Utilities", "Системалык утилиталар"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ToolCardButton(
                            icon: "trash.circle.fill",
                            color: Theme.statusOrange,
                            title: tr("Сбросить DNS кэш", "Flush DNS Cache", "DNS кэшин тазалоо"),
                            subtitle: tr("Очистить кэш dscacheutil и mDNS", "Reset mDNSResponder & dscacheutil", "dscacheutil жана mDNS кэшин тазалоо")
                        ) {
                            manager.flushDNS()
                        }
                        
                        ToolCardButton(
                            icon: "arrow.clockwise.circle.fill",
                            color: Theme.statusBlue,
                            title: tr("Перезапустить службу", "Restart Service", "Кызматты кайра иштетүү"),
                            subtitle: manager.mode == "full"
                                ? (tr("Перезапуск локального dnsmasq", "Restart the local dnsmasq resolver", "Локалдык dnsmasq'ты кайра иштетүү"))
                                : (tr("Доступно в локальном режиме", "Available in local mode", "Локалдык режимде жеткиликтүү")),
                            isEnabled: manager.mode == "full"
                        ) {
                            manager.restartLocalService()
                        }
                        
                        ToolCardButton(
                            icon: "network",
                            color: Theme.statusPurple,
                            title: tr("Настройки сети macOS", "macOS Network Settings", "macOS тармак жөндөөлөрү"),
                            subtitle: tr("Открыть Системные настройки", "Open System Settings panel", "Системалык жөндөөлөрдү ачуу")
                        ) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        
                        ToolCardButton(
                            icon: "doc.text.magnifyingglass",
                            color: Theme.statusGreen,
                            // Подпись обещала «проверку интерфейсов», а кнопка
                            // запускала тест доменов и бенчмарк резолверов.
                            title: tr("Проверка блокировки", "Blocking Check", "Бөгөттөөнү текшерүү"),
                            subtitle: tr("Тест доменов и замер DNS-серверов", "Domain test and DNS benchmark", "Домендерди тестирлөө жана DNS серверлерин өлчөө")
                        ) {
                            manager.runDiagnostics()
                            manager.runSpeedTest()
                        }
                    }
                }
                
                // Network Interfaces Table
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Сетевые подключения macOS", "macOS Network Services", "macOS тармак туташуулары"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 4) {
                        if manager.networkServices.isEmpty {
                            Text(tr("Интерфейсы опрашиваются...", "Querying interfaces...", "Интерфейстер суралып жатат..."))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(12)
                        } else {
                            ForEach(manager.networkServices) { svc in
                                HStack {
                                    Image(systemName: serviceIcon(svc.service))
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.statusBlue)
                                        .frame(width: 22)
                                    
                                    Text(svc.service)
                                        .font(.system(size: 12.5, weight: .semibold))
                                    
                                    Spacer()
                                    
                                    Text(svc.servers)
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.02))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // Live Console Logs
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(tr("Журнал событий", "Event Log", "Окуялар журналы"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Search inside logs
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            TextField(tr("Фильтр лога...", "Filter log...", "Лог чыпкасы..."), text: $logSearch)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .frame(maxWidth: 160)
                        
                        Button(action: copyLogs) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(tr("Скопировать весь журнал", "Copy the whole log", "Бүт журналды көчүрүү"))
                        .accessibilityLabel(tr("Скопировать журнал", "Copy the log", "Журналды көчүрүү"))
                        
                        Button(action: {
                            manager.logEntries.removeAll()
                        }) {
                            Text(tr("Очистить", "Clear", "Тазалоо"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                let entries = filteredLogEntries
                                if entries.isEmpty {
                                    Text(tr("Журнал пуст", "Log is empty", "Журнал бош"))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .padding(8)
                                } else {
                                    ForEach(entries) { entry in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text(dateFormatter.string(from: entry.timestamp))
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                            
                                            Text(entry.text)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(entry.isError ? Theme.statusRed : .primary)
                                        }
                                        .id(entry.id)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                        }
                        .frame(height: 150)
                        .background(Color.black.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .onChange(of: manager.logEntries.count) { _ in
                            if autoScroll, let last = manager.logEntries.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                // Uninstall Section
                VStack(alignment: .leading, spacing: 10) {
                    Text(tr("Сброс и деинсталляция", "Reset & Uninstall", "Тазалоо жана жок кылуу"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.statusRed)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Удалить Cerberus DNS и восстановить настройки сети", "Remove Cerberus DNS and restore network settings", "Cerberus DNS'ти жок кылып, тармак жөндөөлөрүн калыбына келтирүү"))
                                .font(.system(size: 13, weight: .semibold))
                            
                            Text(tr("Останавливает службы, очищает правила и возвращает DNS к исходным значениям.", "Stops services, clears rules and restores the original DNS settings.", "Кызматтарды токтотот, эрежелерди тазалайт жана DNS'ти баштапкы маанилерине кайтарат."))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showUninstallAlert = true
                        }) {
                            Text(tr("Удалить всё", "Remove everything", "Баарын жок кылуу"))
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Theme.statusRed)
                                .foregroundColor(Theme.readableForeground(on: Theme.statusRed))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .bentoCard(cornerRadius: 16, padding: 14)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        // Полный список служб приходит только при явном обновлении — просим
        // его при открытии вкладки, где он и показывается.
        .onAppear { manager.refreshStatus() }
        .alert(isPresented: $showUninstallAlert) {
            Alert(
                title: Text(tr("Удалить Cerberus DNS?", "Remove Cerberus DNS?", "Cerberus DNS жок кылынсынбы?")),
                message: Text(tr("Все службы будут остановлены, базы очищены, а настройки DNS на всех интерфейсах вернутся в исходное состояние.", "All services stop, rule databases are cleared, and DNS settings on every interface return to their original state.", "Бардык кызматтар токтотулат, базалар тазаланат, ал эми бардык интерфейстердеги DNS жөндөөлөрү баштапкы абалына кайтат.")),
                primaryButton: .destructive(Text(tr("Да, удалить всё", "Yes, remove everything", "Ооба, баарын жок кылуу"))) {
                    manager.uninstallAll()
                },
                secondaryButton: .cancel(Text(tr("Отмена", "Cancel", "Жокко чыгаруу")))
            )
        }
    }
    
    private var isRu: Bool { l10n.currentLanguage == .ru }

    private var filteredLogEntries: [LogEntry] {
        if logSearch.trimmingCharacters(in: .whitespaces).isEmpty {
            return manager.logEntries
        }
        return manager.logEntries.filter { $0.text.localizedCaseInsensitiveContains(logSearch) }
    }
    
    /// Один формат на всё представление: раньше `DateFormatter` создавался
    /// заново для каждой строки журнала на каждой перерисовке.
    private static let logTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var dateFormatter: DateFormatter { Self.logTimeFormatter }
    
    private func copyLogs() {
        let full = manager.logEntries.map { "[\(dateFormatter.string(from: $0.timestamp))] \($0.text)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(full, forType: .string)
        manager.showBanner(tr("Журнал скопирован в буфер обмена", "Log copied to clipboard", "Журнал алмашуу буферине көчүрүлдү"))
    }
    
    private func serviceIcon(_ name: String) -> String {
        if name.contains("Wi-Fi") { return "wifi" }
        if name.contains("Ethernet") || name.contains("LAN") { return "cable.connector" }
        if name.contains("Thunderbolt") { return "bolt.horizontal.fill" }
        if name.contains("iPhone") { return "iphone" }
        if name.contains("VPN") || name.contains("Tun") { return "lock.shield" }
        return "network"
    }
}

// MARK: - Tool Card Button
struct ToolCardButton: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    var isEnabled: Bool = true
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.18))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .bold))
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(minHeight: 60)
            .background(isHovered ? Color.primary.opacity(0.04) : Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isHovered ? color.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .onHover { h in isHovered = isEnabled && h }
    }
}
