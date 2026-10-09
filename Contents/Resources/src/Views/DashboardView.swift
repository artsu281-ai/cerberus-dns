import SwiftUI

struct DashboardView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject var l10n = LocalizationManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // MARK: - Active Pause Countdown Card (if paused)
                if manager.isPaused {
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.statusOrange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Защита временно приостановлена", "Protection Temporarily Paused", "Коргоо убактылуу токтотулду"))
                                .font(.system(size: 13, weight: .bold))
                            Text(String(format: tr("Осталось: %@", "Time remaining: %@", "Калды: %@"), manager.formattedPauseRemaining))
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { manager.resumeProtection() }) {
                            Text(tr("Включить сейчас", "Resume Now", "Азыр күйгүзүү"))
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.accentGreen)
                                .foregroundColor(Theme.onAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Theme.statusOrange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.statusOrange.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // MARK: - Перехват системного DNS
                // Самая важная карточка на экране: без неё приложение
                // рапортовало «Защита активна», пока весь DNS-трафик шёл мимо
                // настроенного резолвера и не фильтровался вообще.
                if manager.dnsOverridden {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Theme.statusRed)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(tr("Системный DNS перехвачен — фильтрация не работает", "System DNS is overridden — filtering is inactive", "Системалык DNS кармалып алынган — чыпкалоо иштебейт"))
                                .font(.system(size: 13, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(overrideExplanation)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        // Если перехват устроил Tailscale, предлагаем не
                        // «посмотреть на проблему», а решить её одной кнопкой.
                        if manager.canFixTailscaleConflict {
                            Button(action: { manager.enableTailscaleSplit() }) {
                                Text(tr("Настроить", "Fix it", "Жөндөө"))
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.accentGreen)
                                    .foregroundColor(Theme.onAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .help(tr("Имена tailnet останутся за Tailscale, остальные запросы пойдут через фильтр", "Tailnet names stay with Tailscale, everything else goes through the filter", "tailnet аттары Tailscale тарапта калат, калган сурамдар чыпка аркылуу өтөт"))
                        } else {
                            Button(action: { manager.selectedTab = .diagnostics }) {
                                Text(tr("Проверить", "Diagnose", "Текшерүү"))
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.statusRed)
                                    .foregroundColor(Theme.readableForeground(on: Theme.statusRed))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Theme.statusRed.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.statusRed.opacity(0.35), lineWidth: 1)
                    )
                }

                // MARK: - Native Apple Control Center Hero Card
                HStack(spacing: 16) {
                    // Status Icon Tile
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(heroStatusColor.opacity(0.15))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: manager.isProtectionBypassed ? "shield.lefthalf.filled.slash" : (manager.isProtected ? "shield.fill" : "shield.slash.fill"))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(heroStatusColor)
                    }
                    
                    // Status Info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(heroStatusColor)
                                .frame(width: 7, height: 7)
                            
                            Text(heroStatusTitle)
                                .font(.system(size: 15, weight: .bold))
                        }
                        
                        Text(manager.isProtected ?
                             String(format: L("dashboard.hero.active_sub"), manager.currentProfile.title, manager.currentProfile.subtitle) :
                             L("dashboard.hero.inactive_sub"))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Native Toggle Control
                    Toggle("", isOn: Binding(
                        get: { manager.isProtected },
                        set: { _ in manager.toggleProtection() }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentGreen))
                    .scaleEffect(0.9)
                }
                .padding(14)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                
                // MARK: - Quick Pause Protection Bar
                if manager.isProtected {
                    HStack(spacing: 8) {
                        Text(tr("Пауза защиты:", "Pause:", "Коргоону тындыруу:"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        ForEach(PauseDuration.allCases) { dur in
                            Button(action: { manager.pauseProtection(for: dur) }) {
                                Text(dur.title)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Theme.controlBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                    }
                }
                
                // MARK: - 4 Harmonized Bento Tiles (2x2 Grid with Strict 120px Height)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    // Tile 1: Ad-Block Status
                    DashboardBentoTile(
                        icon: "shield.checkerboard",
                        iconColor: manager.isAdBlocked ? Theme.accentGreen : Theme.statusOrange,
                        title: L("metric.adblock"),
                        badgeText: nil,
                        actionTitle: tr("Тест", "Test", "Тест"),
                        onAction: { manager.runDiagnostics() },
                        mainValue: adBlockValue,
                        subtitle: adBlockSubtitle
                    )
                    
                    // Tile 2: Ping & Sparkline Chart
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(pingColor.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(pingColor)
                            }
                            
                            Text(L("metric.ping"))
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(pingQuality)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(pingColor.opacity(0.15))
                                .foregroundColor(pingColor)
                                .clipShape(Capsule())
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.currentPingMs >= 0 ? "\(manager.currentPingMs) ms" : "—")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            
                            SparklineChartView(points: manager.latencyHistory, color: pingColor)
                                .frame(height: 20)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(height: 120)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // Tile 3: Rule Count
                    DashboardBentoTile(
                        icon: "list.bullet.rectangle",
                        iconColor: Theme.statusBlue,
                        title: L("metric.rules"),
                        badgeText: nil,
                        actionTitle: tr("Обновить", "Update", "Жаңыртуу"),
                        onAction: { manager.updateBlocklists() },
                        mainValue: manager.mode == "full" && manager.domainsCount > 0 ? String(format: L("metric.rules.domains"), manager.domainsCount) : L("metric.rules.cloud"),
                        subtitle: manager.lastUpdated.isEmpty ? "OISD + StevenBlack" : "\(manager.lastUpdated)"
                    )
                    
                    // Tile 4: Current DNS
                    DashboardBentoTile(
                        icon: "network",
                        iconColor: Theme.statusPurple,
                        title: L("metric.current_dns"),
                        badgeText: nil,
                        actionTitle: tr("Сброс", "Flush", "Тазалоо"),
                        onAction: { manager.flushDNS() },
                        mainValue: currentDNSDisplay,
                        subtitle: primaryNetworkName
                    )
                }
                
                // MARK: - Live Traffic & Savings Bento Card
                HStack(spacing: 12) {
                    // Traffic & Time Savings
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.statusGreen)
                            Text(tr("Экономия трафика", "Data Savings", "Трафикти үнөмдөө"))
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            if manager.isQueryStreamSimulated {
                                Text(tr("Оценка", "Estimated", "Болжол"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: tr("%.1f МБ", "%.1f MB", "%.1f МБ"), manager.analytics.dataSavedMB))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.statusGreen)
                                Text(tr("Трафик сэкономлен", "Data saved", "Үнөмдөлгөн трафик"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: tr("%.1f с", "%.1f s", "%.1f сек"), manager.analytics.timeSavedSec))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.statusBlue)
                                Text(tr("Время загрузки", "Time saved", "Жүктөө убактысы"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // Top Blocked Trackers
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shield.slash.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.statusRed)
                            Text(tr("Топ трекеров", "Top Trackers", "Эң көп трекерлер"))
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                        }
                        
                        VStack(spacing: 4) {
                            // Карточка оставалась пустой прямоугольной дырой,
                            // пока не набралось ни одного заблокированного домена.
                            if manager.analytics.topTrackers.isEmpty {
                                Text(tr("Пока ничего не заблокировано", "Nothing blocked yet", "Азырынча эч нерсе бөгөттөлгөн жок"))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            ForEach(manager.analytics.topTrackers.prefix(3)) { item in
                                HStack {
                                    Text(item.domain)
                                        .font(.system(size: 10.5))
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // MARK: - Perfectly Balanced 3-Column Action Strip
                HStack(spacing: 10) {
                    DashboardQuickActionButton(
                        icon: "waveform.path.ecg",
                        title: tr("Диагностика", "Diagnostics", "Диагностика"),
                        subtitle: tr("Тест 12 доменов", "Test 12 ad domains", "12 домен тести"),
                        action: { manager.runDiagnostics() }
                    )
                    
                    DashboardQuickActionButton(
                        icon: "trash.circle",
                        title: tr("Сброс кэша", "Flush DNS Cache", "Кэшти тазалоо"),
                        subtitle: tr("Очистить кэш macOS", "Reset mDNSResponder", "macOS кэшин тазалоо"),
                        action: { manager.flushDNS() }
                    )
                    
                    DashboardQuickActionButton(
                        icon: "speedometer",
                        title: tr("Тест скорости", "Speed Benchmark", "Ылдамдык тести"),
                        subtitle: tr("Замер всех DNS", "Benchmark all servers", "Бардык DNS серверлерин өлчөө"),
                        action: { manager.runSpeedTest() }
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
    }
    
    private var isRu: Bool { l10n.currentLanguage == .ru }

    private var heroStatusTitle: String {
        if manager.isProtectionBypassed {
            return tr("Защита настроена, но не действует", "Configured but not in effect", "Коргоо жөндөлгөн, бирок иштебей жатат")
        }
        return manager.isProtected ? L("status.active") : L("status.unprotected")
    }

    private var heroStatusColor: Color {
        if manager.isProtectionBypassed { return Theme.statusOrange }
        return manager.isProtected ? Theme.accentGreen : Color.secondary
    }

    private var overrideExplanation: String {
        if manager.canFixTailscaleConflict {
            let suffix = manager.tailscale?.suffix ?? "ts.net"
            return tr("Запросы уходят в Tailscale, минуя фильтр. Спорить с ним бесполезно — можно разделить зоны: имена \(suffix) останутся за Tailscale, все остальные пойдут через фильтр.", "Queries go to Tailscale, bypassing the filter. Fighting it is pointless — the zones can be split instead: \(suffix) names stay with Tailscale, everything else goes through the filter.", "Сурамдар чыпканы айланып өтүп, Tailscale аркылуу кетет. Аны менен талашуунун пайдасы жок — зоналарды бөлүүгө болот: \(suffix) аттары Tailscale тарапта калат, калгандары чыпка аркылуу өтөт.")
        }
        let source = manager.overrideSource.isEmpty
            ? (tr("сторонний резолвер", "another resolver", "башка резолвер"))
            : manager.overrideSource
        let resolver = manager.effectiveResolver.isEmpty ? "—" : manager.effectiveResolver
        return tr("Запросы уходят на \(resolver) (\(source)), минуя выбранный вами DNS. Отключите этот источник или настройте фильтрацию в нём.", "Queries go to \(resolver) (\(source)), bypassing your DNS. Disable that source or configure filtering there.", "Сурамдар сиз тандаган DNS серверин айланып өтүп, \(resolver) (\(source)) дарегине кетет. Бул булакты өчүрүңүз же андагы чыпкалоону жөндөңүз.")
    }

    /// Плитка показывает результат замера, а не состояние переключателя.
    /// Раньше здесь было «Отключена» даже при включённой защите — просто
    /// потому, что контрольный домен всё-таки разрешился.
    private var adBlockValue: String {
        if manager.isAdBlocked { return L("metric.adblock.active") }
        if manager.isProtected { return tr("Не подтверждена", "Not confirmed", "Тастыкталган жок") }
        return L("metric.adblock.inactive")
    }

    private var adBlockSubtitle: String {
        if manager.isAdBlocked { return L("metric.adblock.active_sub") }
        if manager.isProtected {
            return tr("Контрольный домен всё ещё разрешается", "Control domain still resolves", "Контролдук домен дагы эле ачылып жатат")
        }
        return L("metric.adblock.inactive_sub")
    }

    /// Активный сетевой интерфейс, из которого берутся реальные адреса DNS.
    private var activeService: NetworkServiceInfo? {
        manager.networkServices.first(where: { $0.service == "Wi-Fi" })
            ?? manager.networkServices.first(where: { $0.service.contains("Ethernet") || $0.service.contains("LAN") })
            ?? manager.networkServices.first
    }

    /// Фактический резолвер системы.
    /// Прежняя версия печатала сюда `profile.servers`, поэтому для профиля
    /// «Пользовательский DNS» на экране появлялась строка «По выбору».
    private var currentDNSDisplay: String {
        if !manager.effectiveResolver.isEmpty { return manager.effectiveResolver }
        if let servers = activeService?.servers {
            let first = servers
                .components(separatedBy: CharacterSet(charactersIn: ", "))
                .first(where: { !$0.isEmpty })
            if let first = first { return first }
        }
        return manager.isProtected ? "—" : "DHCP"
    }
    
    private var primaryNetworkName: String {
        if manager.dnsOverridden && !manager.effectiveInterface.isEmpty {
            return tr("перехват через \(manager.effectiveInterface)", "via \(manager.effectiveInterface)", "\(manager.effectiveInterface) аркылуу кармалган")
        }
        if let svc = activeService { return svc.service }
        return tr("Нет активных интерфейсов", "No active interfaces", "Активдүү интерфейстер жок")
    }

    /// Пороги задержки. Одна таблица на всё приложение — в шапке окна
    /// раньше действовали другие границы (60/140), и один и тот же пинг
    /// подсвечивался там зелёным, а здесь оранжевым.
    private var pingColor: Color { Theme.pingColor(manager.currentPingMs) }
    
    private var pingQuality: String {
        let ms = manager.currentPingMs
        if ms < 0 { return L("ping.testing") }
        if ms < 30 { return L("ping.perfect") }
        if ms < 80 { return L("ping.fast") }
        if ms < 140 { return L("ping.normal") }
        return L("ping.slow")
    }
}

// MARK: - Harmonized Bento Tile Component (Strict 120px Height)
struct DashboardBentoTile: View {
    let icon: String
    let iconColor: Color
    let title: String
    let badgeText: String?
    let actionTitle: String
    let onAction: () -> Void
    let mainValue: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row (Icon + Title + Action Button)
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            
            // Value and Subtitle Row
            VStack(alignment: .leading, spacing: 2) {
                Text(mainValue)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: 120)
        .background(Theme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Sparkline Chart Component
struct SparklineChartView: View {
    let points: [LatencyPoint]
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            if points.count > 1 {
                let maxVal = max(100, points.map { $0.latencyMs }.max() ?? 100)
                let minVal = 0
                let stepX = geo.size.width / CGFloat(points.count - 1)
                
                Path { path in
                    for (i, p) in points.enumerated() {
                        let x = CGFloat(i) * stepX
                        let ratio = CGFloat(p.latencyMs - minVal) / CGFloat(maxVal - minVal)
                        let y = geo.size.height - (ratio * geo.size.height)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            } else {
                HStack {
                    Capsule()
                        .fill(color.opacity(0.2))
                        .frame(height: 1.5)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Clean Quick Action Button Component
struct DashboardQuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.accent.opacity(isHovered ? 0.18 : 0.08))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(height: 52)
            .background(isHovered ? Color.primary.opacity(0.04) : Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isHovered ? Theme.accent.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }
}
