import SwiftUI

struct RulesView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var selectedRuleType: Int = 0 // 0: Whitelist, 1: Blacklist
    @State private var searchQuery: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Списки фильтрации и исключения", "Filter Lists & Custom Rules", "Чыпкалоо тизмелери жана өзгөчөлүктөр"))
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(tr("Управление источниками правил, белым списком исключений и собственными черными списками.", "Manage community filter sources, whitelist bypasses, and custom blocklist rules.", "Эрежелердин булактарын, өзгөчөлүктөрдүн ак тизмесин жана өз кара тизмелериңизди башкаруу."))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Filter Sources Bento Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.statusBlue.opacity(0.15))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "cylinder.split.1x2.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.statusBlue)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            // Заголовок обещал «340 000+ правил» независимо от
                            // того, скачаны ли базы вообще.
                            Text(sourcesTitle)
                                .font(.system(size: 13, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text(sourcesSubtitle)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            manager.updateBlocklists()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(tr("Обновить", "Update", "Жаңыртуу"))
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.accent)
                            .foregroundColor(Theme.onAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Sources pills (Adaptive Grid)
                    // Минимум 140 pt не вмещал «StevenBlack» вместе с адресом —
                    // подписи рвались посреди слова.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190, maximum: .infinity), spacing: 8)], spacing: 8) {
                        // Счётчики «250K / 85K / 12K» были константами и
                        // показывались даже когда базы не скачаны, а сам
                        // локальный режим выключен. Движок отдаёт только общее
                        // число правил, поэтому показываем состояние источника,
                        // а не выдуманное количество строк в каждом из них.
                        ForEach(blocklistSources, id: \.0) { source in
                            SourcePill(name: source.0, count: source.1, isEnabled: sourcesActive)
                        }
                    }
                }
                .padding(14)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                
                // MARK: - Pixel-Perfect Rules Control Bar
                VStack(spacing: 10) {
                    // Row 1: Custom Aligned Segmented Control & Add Button
                    HStack(spacing: 12) {
                        // Custom Pixel-Perfect Segmented Control
                        HStack(spacing: 4) {
                            RuleTabSegmentButton(
                                title: tr("Белый список", "Whitelist", "Ак тизме"),
                                icon: "checkmark.shield.fill",
                                count: manager.whitelistDomains.count,
                                isSelected: selectedRuleType == 0,
                                activeColor: Theme.statusGreen
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedRuleType = 0
                                }
                            }
                            
                            RuleTabSegmentButton(
                                title: tr("Чёрный список", "Blacklist", "Кара тизме"),
                                icon: "nosign",
                                count: manager.blacklistDomains.count,
                                isSelected: selectedRuleType == 1,
                                activeColor: Theme.statusRed
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedRuleType = 1
                                }
                            }
                        }
                        .padding(3)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        Spacer()
                        
                        // Add Rule Button
                        Button(action: {
                            manager.showAddRuleSheet = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                Text(tr("Добавить правило", "Add Rule", "Эреже кошуу"))
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.accent)
                            .foregroundColor(Theme.onAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if manager.isProtected && manager.currentProfileId != "local_dnsmasq" {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Theme.statusOrange)
                                .font(.system(size: 13))
                            Text(tr("Сейчас активен облачный профиль. Пользовательские правила применяются только в профиле «Локальный dnsmasq».", "A cloud DNS profile is active. Custom whitelist and blacklist rules only apply in the “Local dnsmasq” profile.", "Азыр булуттагы профиль активдүү. Колдонуучунун эрежелери «Локалдык dnsmasq» профилинде гана колдонулат."))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(10)
                        .background(Theme.statusOrange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    
                    // Row 2: Search Bar Aligned to Container Edges
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        TextField(tr("Поиск по доменам...", "Filter domains...", "Домендер боюнча издөө..."), text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tr("Очистить поле", "Clear the field", "Талааны тазалоо"))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                // MARK: - Domain Rules List Container
                VStack(spacing: 6) {
                    let items = currentFilteredList
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: selectedRuleType == 0 ? "checkmark.shield" : "shield.slash")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Text(searchQuery.isEmpty ?
                                 (tr("Список пуст", "List is empty", "Тизме бош")) :
                                 (tr("Ничего не найдено", "No matching domains", "Эч нерсе табылган жок")))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    } else {
                        ForEach(items, id: \.self) { dom in
                            DomainRow(domain: dom, isWhitelist: selectedRuleType == 0) {
                                if selectedRuleType == 0 {
                                    manager.removeWhitelistDomain(dom)
                                } else {
                                    manager.removeBlacklistDomain(dom)
                                }
                            }
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
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .sheet(isPresented: $manager.showAddRuleSheet) {
            AddRuleSheet(
                isWhitelist: selectedRuleType == 0,
                onAdd: { domain in
                    if selectedRuleType == 0 {
                        manager.addWhitelistDomain(domain)
                    } else {
                        manager.addBlacklistDomain(domain)
                    }
                    manager.showAddRuleSheet = false
                },
                onCancel: {
                    manager.showAddRuleSheet = false
                }
            )
        }
    }
    
    private var isRu: Bool { l10n.currentLanguage == .ru }

    /// Локальные базы применяются только в режиме локального dnsmasq.
    private var sourcesActive: Bool {
        manager.mode == "full" && manager.domainsCount > 0
    }

    private var sourcesTitle: String {
        if sourcesActive {
            let formatted = NumberFormatter.localizedString(
                from: NSNumber(value: manager.domainsCount), number: .decimal)
            return tr("Источники баз блокировки — \(formatted) правил", "Blocklist sources — \(formatted) rules", "Бөгөттөө базаларынын булактары — \(formatted) эреже")
        }
        return tr("Источники баз блокировки (локальный режим выключен)", "Blocklist sources (local mode is off)", "Бөгөттөө базаларынын булактары (локалдык режим өчүк)")
    }

    private var sourcesSubtitle: String {
        if !manager.lastUpdated.isEmpty {
            return (tr("Обновлено: ", "Updated: ", "Жаңыртылды: ")) + manager.lastUpdated
        }
        if sourcesActive { return tr("Базы загружены", "Databases loaded", "Базалар жүктөлдү") }
        return tr("Загружаются в режиме «Локальный dnsmasq»; облачные профили фильтруют на стороне провайдера DNS", "Downloaded in “Local dnsmasq” mode; cloud profiles filter on the DNS provider side", "«Локалдык dnsmasq» режиминде жүктөлөт; булуттагы профилдер DNS провайдеринин тарабында чыпкалайт")
    }

    private var blocklistSources: [(String, String)] {
        [(tr("OISD Big (основной)", "OISD Big (primary)", "OISD Big (негизги)"), "big.oisd.nl"),
         (tr("StevenBlack (зеркало)", "StevenBlack (mirror)", "StevenBlack (күзгү)"), "github.com"),
         (tr("AdAway (зеркало)", "AdAway (mirror)", "AdAway (күзгү)"), "adaway.org")]
    }

    private var currentFilteredList: [String] {
        let list = (selectedRuleType == 0) ? manager.whitelistDomains : manager.blacklistDomains
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return list
        }
        return list.filter { $0.localizedCaseInsensitiveContains(searchQuery) }
    }
}

// MARK: - Rule Tab Segment Button Component
struct RuleTabSegmentButton: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let activeColor: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? activeColor : .secondary)
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? activeColor.opacity(0.18) : Color.primary.opacity(0.06))
                        .foregroundColor(isSelected ? activeColor : .secondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Theme.controlBackground : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
                    .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }
}

// MARK: - Add Rule Sheet Modal
struct AddRuleSheet: View {
    let isWhitelist: Bool
    let onAdd: (String) -> Void
    let onCancel: () -> Void
    
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var domain: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isWhitelist ?
                     (tr("Добавить в белый список", "Add to Whitelist", "Ак тизмеге кошуу")) :
                     (tr("Добавить в чёрный список", "Add to Blacklist", "Кара тизмеге кошуу")))
                    .font(.system(size: 15, weight: .bold))
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Закрыть", "Close", "Жабуу"))
            }
            
            Text(isWhitelist ?
                 (tr("Домены из белого списка никогда не блокируются фильтрами.", "Whitelisted domains will always bypass DNS filtering.", "Ак тизмедеги домендер чыпкалар менен эч качан бөгөттөлбөйт.")) :
                 (tr("Домены из чёрного списка будут принудительно заблокированы на вашем Mac.", "Blacklisted domains will be strictly blocked across your network.", "Кара тизмедеги домендер Mac'иңизде милдеттүү түрдө бөгөттөлөт.")))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Доменное имя:", "Domain Name:", "Домендин аты:"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("example.com", text: $domain)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { submit() }

                // Обратная связь до отправки: поле принимало любую строку,
                // а неверное правило разваливало конфигурацию dnsmasq.
                HStack(spacing: 5) {
                    Image(systemName: validationIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(validationColor)
                    Text(validationMessage)
                        .font(.system(size: 10.5))
                        .foregroundColor(validationColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(height: 26, alignment: .top)
            }
            
            HStack {
                Spacer()
                
                Button(tr("Отмена", "Cancel", "Жокко чыгаруу"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button(action: submit) {
                    Text(isWhitelist ?
                         (tr("Разрешить", "Allow", "Уруксат берүү")) :
                         (tr("Заблокировать", "Block", "Бөгөттөө")))
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(isWhitelist ? Theme.statusGreen : Theme.statusRed)
                        .foregroundColor(Theme.readableForeground(on: isWhitelist ? Theme.statusGreen : Theme.statusRed))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(sanitizedDomain == nil)
                .opacity(sanitizedDomain == nil ? 0.5 : 1.0)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(width: 400)
    }

    private var isRu: Bool { l10n.currentLanguage == .ru }

    private var sanitizedDomain: String? { DomainValidator.sanitized(domain) }

    private func submit() {
        guard let clean = sanitizedDomain else { return }
        onAdd(clean)
    }

    private var validationIcon: String {
        if domain.trimmingCharacters(in: .whitespaces).isEmpty { return "info.circle" }
        return sanitizedDomain == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var validationColor: Color {
        if domain.trimmingCharacters(in: .whitespaces).isEmpty { return .secondary }
        return sanitizedDomain == nil ? Theme.statusRed : Theme.statusGreen
    }

    private var validationMessage: String {
        if domain.trimmingCharacters(in: .whitespaces).isEmpty {
            return tr("Только имя хоста, без http:// и путей", "Host name only — no scheme or path", "Хосттун аты гана, http:// жана жолдорсуз")
        }
        guard let clean = sanitizedDomain else {
            return tr("Не похоже на доменное имя", "This is not a valid domain name", "Домендин атына окшобойт")
        }
        if clean != domain.trimmingCharacters(in: .whitespaces).lowercased() {
            return (tr("Будет добавлено: ", "Will be added as: ", "Кошулат: ")) + clean
        }
        return tr("Корректное доменное имя", "Valid domain name", "Туура домен аты")
    }
}

// MARK: - Source Pill
struct SourcePill: View {
    let name: String
    let count: String
    let isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isEnabled ? Theme.statusGreen : Color.secondary)
                .frame(width: 5, height: 5)
            
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            Spacer(minLength: 6)
            
            Text(count)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Domain Row
struct DomainRow: View {
    let domain: String
    let isWhitelist: Bool
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Image(systemName: isWhitelist ? "checkmark.circle.fill" : "nosign")
                .foregroundColor(isWhitelist ? Theme.statusGreen : Theme.statusRed)
                .font(.system(size: 12))
            
            Text(domain)
                .font(.system(size: 12, design: .monospaced))
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(isHovered ? .red : .secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("Удалить правило \(domain)", "Remove rule \(domain)", "\(domain) эрежесин жок кылуу"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { h in isHovered = h }
    }
}
