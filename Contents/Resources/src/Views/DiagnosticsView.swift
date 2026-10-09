import SwiftUI
import AppKit

struct DiagnosticsView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject var l10n = LocalizationManager.shared
    
    @State private var activeSegment: Int = 0 // 0: Tracker test, 1: Full Speedtest Pro, 2: DNS Benchmark
    /// Ключ, а не подпись: см. `DiagnosticItem.group`.
    @State private var selectedCategoryKey: String = "all"

    private var isRu: Bool { l10n.currentLanguage == .ru }
    
    private var categories: [(key: String, title: String)] {
        [("all",       tr("Все", "All", "Баары")),
         ("ads",       tr("Реклама", "Ads", "Жарнама")),
         ("analytics", tr("Аналитика", "Analytics", "Аналитика")),
         ("trackers",  tr("Трекеры", "Trackers", "Трекерлер")),
         ("telemetry", tr("Телеметрия", "Telemetry", "Телеметрия"))]
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Диагностика и Аналитика", "Diagnostics & Speed Benchmark", "Диагностика жана Аналитика"))
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                    
                    Text(tr("Проверка устойчивости к рекламным трекерам, замер скорости интернет-канала и бенчмарк DNS-серверов.", "Verify tracker blocking efficiency, run full bandwidth speedtest, and benchmark live DNS latency.", "Жарнамалык трекерлерге туруктуулукту текшерүү, интернет каналынын ылдамдыгын өлчөө жана DNS-серверлердин бенчмаркы."))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // MARK: - 3-Way Sub-Tab Segment Switcher (Consistent Segmented Style)
                HStack(spacing: 8) {
                    DiagnosticSubTabButton(
                        title: tr("Проверка трекеров", "Tracker Shield", "Трекерлерди текшерүү"),
                        icon: "shield.checkerboard",
                        isSelected: activeSegment == 0
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { activeSegment = 0 }
                    }
                    
                    DiagnosticSubTabButton(
                        title: tr("Спидтест сети", "Speedtest Pro", "Тармактын спидтести"),
                        icon: "speedometer",
                        isSelected: activeSegment == 1
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { activeSegment = 1 }
                    }
                    
                    DiagnosticSubTabButton(
                        title: tr("Бенчмарк DNS", "DNS Benchmark", "DNS бенчмаркы"),
                        icon: "bolt.fill",
                        isSelected: activeSegment == 2
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { activeSegment = 2 }
                        if manager.speedTestResults.isEmpty && !manager.isSpeedTesting {
                            manager.runSpeedTest()
                        }
                    }
                }
                .padding(6)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                
                // MARK: - Active Section Content
                if activeSegment == 0 {
                    adBlockSection
                } else if activeSegment == 1 {
                    fullSpeedtestSection
                } else {
                    speedBenchmarkSection
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .onAppear {
            if manager.diagnosticResults.isEmpty && !manager.isDiagnosing {
                manager.runDiagnostics()
            }
        }
    }
    
    // MARK: - 1. Ad Block Section View
    private var adBlockSection: some View {
        VStack(spacing: 14) {
            // Efficiency Gauge Banner
            HStack(spacing: 16) {
                // Circular Gauge
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 5)
                        .frame(width: 52, height: 52)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(adBlockEfficiency) / 100.0)
                        .stroke(
                            adBlockEfficiency > 70 ? Theme.accentGreen : (adBlockEfficiency > 30 ? Theme.statusOrange : Theme.statusRed),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(adBlockEfficiency)%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text(tr("защита", "score", "коргоо"))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(efficiencyTitle)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    
                    Text(efficiencyDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 8)
                
                VStack(alignment: .trailing, spacing: 6) {
                    Button(action: {
                        manager.runDiagnostics()
                    }) {
                        HStack(spacing: 4) {
                            if manager.isDiagnosing {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(manager.isDiagnosing ?
                                 (tr("Тест...", "Testing...", "Тест...")) :
                                 (tr("Запустить тест", "Run Test", "Тестти баштоо")))
                                .lineLimit(1)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.accent)
                        .foregroundColor(Theme.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(manager.isDiagnosing)
                    
                    Button(action: copyDiagnosticsReport) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text(tr("Копировать отчёт", "Copy Report", "Отчетту көчүрүү"))
                                .lineLimit(1)
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            
            // Браузеры со своим DoH. Тест доменов их не покрывает: он ходит
            // через системный резолвер, а браузер — мимо. Без этой карточки
            // «100% заблокировано» выглядело бы полной правдой, ею не являясь.
            if !manager.browserDoH.isEmpty {
                let bypassing = manager.doHBypassingBrowsers
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: bypassing.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(bypassing.isEmpty ? Theme.statusGreen : Theme.statusOrange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(bypassing.isEmpty
                             ? (tr("Браузеры ходят через системный DNS", "Browsers use the system DNS", "Браузерлер системалык DNS аркылуу иштейт"))
                             : (tr("Мимо фильтра: \(bypassing.map { $0.browser }.joined(separator: ", "))", "Bypassing the filter: \(bypassing.map { $0.browser }.joined(separator: ", "))", "Чыпканы айланып өтөт: \(bypassing.map { $0.browser }.joined(separator: ", "))")))
                            .font(.system(size: 12.5, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(bypassing.isEmpty
                             ? (tr("Собственный DNS-over-HTTPS выключен во всех найденных браузерах — проверка ниже отражает и их трафик.", "Their own DNS-over-HTTPS is off in every browser found, so the check below covers them too.", "Табылган бардык браузерлерде өздүк DNS-over-HTTPS өчүрүлгөн — төмөнкү текшерүү алардын трафигин да камтыйт."))
                             : (tr("Эти браузеры отправляют запросы по HTTPS на свой адрес, минуя системный резолвер. Проверка ниже их не покрывает: в них реклама продолжит загружаться. Отключается в настройках браузера — «Использовать защищённый DNS».", "These browsers send queries over HTTPS to their own endpoint, bypassing the system resolver. The check below does not cover them, and ads will keep loading there. Turn it off under the browser's secure DNS setting.", "Бул браузерлер сурамдарды HTTPS аркылуу өз дарегине жөнөтүп, системалык резолверди айланып өтөт. Төмөнкү текшерүү аларды камтыбайт: аларда жарнама жүктөлө берет. Браузердин жөндөөлөрүнөн өчүрүлөт — «Коопсуз DNS колдонуу».")))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Состояние каждого браузера — чтобы было видно, что
                        // проверено, а не только чего не хватает.
                        HStack(spacing: 6) {
                            ForEach(manager.browserDoH) { b in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(b.bypasses ? Theme.statusOrange : Theme.statusGreen)
                                        .frame(width: 5, height: 5)
                                    Text("\(b.browser) · \(b.modeTitle)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 2)

                        // Блокировка. Ключевое правило — домен-канарейка:
                        // Firefox проверяет его перед включением своего DoH и
                        // отключает DoH сам, если тот не резолвится. Правила
                        // живут в конфиге локального резолвера, поэтому в
                        // облачном режиме отметка сохраняется, но не действует —
                        // и об этом сказано прямо, а не умолчано.
                        HStack(spacing: 8) {
                            Button(action: { manager.setDoHBlocking(!manager.dohBlockingEnabled) }) {
                                HStack(spacing: 5) {
                                    Image(systemName: manager.dohBlockingEnabled ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(manager.dohBlockingEnabled
                                         ? (tr("Сторонний DoH блокируется", "Third-party DoH is blocked", "Бөтөн DoH бөгөттөлөт"))
                                         : (tr("Блокировать сторонний DoH", "Block third-party DoH", "Бөтөн DoH бөгөттөө")))
                                        .font(.system(size: 10.5, weight: .semibold))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(manager.dohBlockingEnabled ? Theme.statusGreen.opacity(0.16) : Color.primary.opacity(0.06))
                                .foregroundColor(manager.dohBlockingEnabled ? Theme.statusGreen : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tr("Блокировать сторонний DNS-over-HTTPS", "Block third-party DNS-over-HTTPS", "Бөтөн DNS-over-HTTPS бөгөттөө"))

                            if manager.mode != "full" {
                                Text(tr("действует только в локальном режиме", "works in local mode only", "локалдык режимде гана иштейт"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.top, 4)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background((bypassing.isEmpty ? Theme.statusGreen : Theme.statusOrange).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke((bypassing.isEmpty ? Theme.statusGreen : Theme.statusOrange).opacity(0.25), lineWidth: 1)
                )
            }

            // Filter Pills (Equal Width & Centered)
            HStack(spacing: 8) {
                ForEach(categories, id: \.key) { cat in
                    Button(action: {
                        selectedCategoryKey = cat.key
                    }) {
                        Text(cat.title)
                            .font(.system(size: 11.5, weight: isCategorySelected(cat.key) ? .semibold : .medium))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(isCategorySelected(cat.key) ? Theme.accent : Color.primary.opacity(0.05))
                            .foregroundColor(isCategorySelected(cat.key) ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            
            // Domain Results List
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Результаты проверки контрольных доменов", "Sample Domains Verification Results", "Контролдук домендерди текшерүүнүн жыйынтыктары"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                
                VStack(spacing: 2) {
                    let items = filteredDiagnostics
                    if items.isEmpty {
                        Text(tr("Нет данных для отображения", "No diagnostic records", "Көрсөтүүгө маалымат жок"))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(20)
                    } else {
                        ForEach(items) { item in
                            DiagnosticDomainRow(item: item)
                        }
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
        }
    }
    
    // MARK: - 2. Full Network Speedtest Pro View
    private var fullSpeedtestSection: some View {
        VStack(spacing: 14) {
            // Speedometer Main Hero Card
            VStack(spacing: 16) {
                // Live Speed Gauge Arc
                ZStack {
                    // Gauge Track
                    Circle()
                        .trim(from: 0.15, to: 0.85)
                        .stroke(Color.primary.opacity(0.06), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 170, height: 170)
                        .rotationEffect(.degrees(90))
                    
                    // Active Gauge Fill
                    let val = manager.isFullSpeedtesting ? manager.liveSpeedGauge : (manager.fullSpeedtestResult?.downloadMbps ?? 0.0)
                    let pct = min(1.0, max(0.0, val / 150.0))
                    Circle()
                        .trim(from: 0.15, to: 0.15 + (pct * 0.70))
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [Theme.accentGreen, Theme.statusBlue, Theme.statusPurple]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 170, height: 170)
                        .rotationEffect(.degrees(90))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: val)
                    
                    // Center Speed Readout
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", val))
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(tr("Мбит/с", "Mbps", "Мбит/с"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        // Status Phase Badge
                        Text(manager.isFullSpeedtesting ? manager.speedtestPhase : (manager.fullSpeedtestResult != nil ? (tr("Готово", "Finished", "Даяр")) : (tr("Ожидание", "Ready", "Күтүү"))))
                            .font(.system(size: 9.5, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(manager.isFullSpeedtesting ? Theme.accent.opacity(0.18) : Color.primary.opacity(0.06))
                            .foregroundColor(manager.isFullSpeedtesting ? Theme.accent : .secondary)
                            .clipShape(Capsule())
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 8)
                
                // Action Trigger Button
                Button(action: {
                    manager.runFullSpeedtest()
                }) {
                    HStack(spacing: 6) {
                        if manager.isFullSpeedtesting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                        }
                        
                        Text(manager.isFullSpeedtesting ?
                             (tr("Тестирование...", "Testing...", "Тестирлөө...")) :
                             (tr("Запустить Speedtest", "Start Speedtest", "Speedtest баштоо")))
                            .font(.system(size: 12.5, weight: .bold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .foregroundColor(Theme.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(manager.isFullSpeedtesting)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            
            // 4 Metrics Bento Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                SpeedtestMetricTile(
                    title: tr("Скачивание", "Download", "Жүктөп алуу"),
                    value: manager.fullSpeedtestResult != nil ? String(format: "%.1f", manager.fullSpeedtestResult!.downloadMbps) : "—",
                    unit: tr("Мбит/с", "Mbps", "Мбит/с"),
                    icon: "arrow.down.circle.fill",
                    iconColor: Theme.accentGreen
                )
                
                SpeedtestMetricTile(
                    title: tr("Выгрузка", "Upload", "Жүктөп берүү"),
                    value: (manager.fullSpeedtestResult?.hasUpload ?? false)
                        ? String(format: "%.1f", manager.fullSpeedtestResult!.uploadMbps) : "—",
                    unit: tr("Мбит/с", "Mbps", "Мбит/с"),
                    icon: "arrow.up.circle.fill",
                    iconColor: Theme.statusBlue
                )
                
                SpeedtestMetricTile(
                    title: tr("Задержка", "Ping RTT", "Кечигүү"),
                    value: manager.fullSpeedtestResult != nil ? "\(manager.fullSpeedtestResult!.pingMs)" : "—",
                    unit: tr("мс", "ms", "мс"),
                    icon: "bolt.fill",
                    iconColor: Theme.statusOrange
                )
                
                SpeedtestMetricTile(
                    title: tr("Джиттер", "Jitter", "Джиттер"),
                    value: manager.fullSpeedtestResult != nil ? String(format: "%.1f", manager.fullSpeedtestResult!.jitterMs) : "—",
                    unit: tr("мс", "ms", "мс"),
                    icon: "waveform.path.ecg",
                    iconColor: Theme.statusPurple
                )
            }
            
            // Server & Network Quality Grade
            if let res = manager.fullSpeedtestResult {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.accentGreen)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(res.qualityGrade)
                            .font(.system(size: 12, weight: .bold))
                        Text(tr("Сервер: \(res.serverName) · потери \(res.packetLossPct)%",
                                "Server: \(res.serverName) · loss \(res.packetLossPct)%", "Сервер: \(res.serverName) · жоготуу \(res.packetLossPct)%"))
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - 3. Speed Benchmark Section View
    private var speedBenchmarkSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Бенчмарк скорости DNS-резолверов", "DNS Resolvers Latency Benchmark", "DNS-резолверлердин ылдамдыгын салыштыруу"))
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    
                    Text(tr("Прямой замер времени ответа (RTT) до глобальных Anycast DNS-серверов в реальном времени.", "Live round-trip time (RTT) measurements to global Anycast DNS providers.", "Глобалдык Anycast DNS-серверлерине чейинки жооп убактысын (RTT) реалдуу убакытта түз өлчөө."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 8)
                
                Button(action: {
                    manager.runSpeedTest()
                }) {
                    HStack(spacing: 4) {
                        if manager.isSpeedTesting {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text(manager.isSpeedTesting ?
                             (tr("Замер...", "Testing...", "Өлчөө...")) :
                             (tr("Запустить бенчмарк", "Run Benchmark", "Бенчмаркты баштоо")))
                            .lineLimit(1)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accent)
                    .foregroundColor(Theme.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(manager.isSpeedTesting)
            }
            .padding(14)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            
            // Speed Test Rows
            VStack(spacing: 4) {
                let items = manager.speedTestResults.sorted(by: {
                    ($0.latencyMs > 0 ? $0.latencyMs : 9999) < ($1.latencyMs > 0 ? $1.latencyMs : 9999)
                })
                
                if items.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text(tr("Выполняется замер скорости...", "Measuring latency...", "Ылдамдык өлчөнүүдө..."))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(30)
                } else {
                    ForEach(items) { speedItem in
                        SpeedTestBarRow(item: speedItem, isFastest: speedItem.id == items.first?.id && speedItem.latencyMs > 0)
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
        }
    }
    
    // Helpers
    private var adBlockEfficiency: Int {
        guard !manager.diagnosticResults.isEmpty else { return 0 }
        // Домены, которые не удалось проверить, исключаются из знаменателя:
        // иначе обрыв сети сначала засчитывался как блокировка, а после
        // исправления движка занижал бы результат.
        let checked = manager.diagnosticResults.filter { !$0.isControl && !$0.didFail }
        guard !checked.isEmpty else { return 0 }
        let blocked = checked.filter { $0.blocked }.count
        return Int((Double(blocked) / Double(checked.count)) * 100.0)
    }
    
    private var efficiencyTitle: String {
        if adBlockEfficiency >= 90 {
            return tr("Максимальная защита от рекламы", "Excellent Ad & Tracker Shield", "Жарнамадан максималдуу коргоо")
        } else if adBlockEfficiency >= 50 {
            return tr("Частичная блокировка трекеров", "Moderate Protection Active", "Трекерлер жарым-жартылай бөгөттөлөт")
        } else {
            return tr("Защита не активна", "Filtering Inactive", "Коргоо активдүү эмес")
        }
    }
    
    private var efficiencyDescription: String {
        if adBlockEfficiency >= 90 {
            return tr("Рекламные домены, трекеры и счетчики блокируются на сетевом уровне.", "Known ad networks, analytics engines, and telemetry domains are blocked.", "Жарнамалык домендер, трекерлер жана эсептегичтер тармак деңгээлинде бөгөттөлөт.")
        } else {
            return tr("Включите профиль блокировки (AdGuard или dnsmasq) на главной панели.", "Enable an active DNS blocking profile on the dashboard to protect traffic.", "Башкы панелде бөгөттөө профилин (AdGuard же dnsmasq) күйгүзүңүз.")
        }
    }
    
    private func isCategorySelected(_ key: String) -> Bool {
        selectedCategoryKey == key
    }
    
    private var filteredDiagnostics: [DiagnosticItem] {
        guard selectedCategoryKey != "all" else { return manager.diagnosticResults }
        return manager.diagnosticResults.filter { $0.group == selectedCategoryKey }
    }
    
    private func copyDiagnosticsReport() {
        var report = "DNS-Blocker Diagnostics Report\n"
        report += "Date: \(Date())\nScore: \(adBlockEfficiency)%\n\n"
        for item in manager.diagnosticResults {
            report += "\(item.domain) [\(item.category)]: \(item.blocked ? "BLOCKED" : "ALLOWED") (\(item.ip))\n"
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(report, forType: .string)
        manager.statusBanner = tr("Отчёт скопирован в буфер обмена", "Report copied to clipboard", "Отчет алмашуу буферине көчүрүлдү")
    }
}

// MARK: - Speedtest Metric Tile Component
struct SpeedtestMetricTile: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(unit)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Diagnostic Sub-Tab Button
struct DiagnosticSubTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isSelected ? Theme.accent : Color.primary.opacity(0.05))
            .foregroundColor(isSelected ? Theme.onAccent : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Diagnostic Domain Row
struct DiagnosticDomainRow: View {
    let item: DiagnosticItem
    @ObservedObject var l10n = LocalizationManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.blocked ? "checkmark.shield.fill" : (item.isControl ? "checkmark.circle" : "exclamationmark.triangle.fill"))
                .foregroundColor(item.blocked ? Theme.accentGreen : (item.isControl ? Theme.statusBlue : Theme.statusOrange))
                .font(.system(size: 12))
            
            Text(item.domain)
                .font(.system(size: 11.5, design: .monospaced))
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            Text(item.localizedCategory)
                .font(.system(size: 10))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // «Пропущен» / «Passed» для нефильтрованного рекламного домена
            // читалось как успешно пройденная проверка, хотя это ровно
            // обратное — реклама прошла насквозь.
            Text(verdictText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(verdictColor)
                .frame(width: 96, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var isRu: Bool { l10n.currentLanguage == .ru }

    private var verdictText: String {
        if item.didFail { return tr("Нет ответа", "No answer", "Жооп жок") }
        if item.blocked { return tr("Заблокирован", "Blocked", "Бөгөттөлдү") }
        if item.isControl { return tr("Доступен", "Reachable", "Жеткиликтүү") }
        return tr("Не заблокирован", "Not blocked", "Бөгөттөлгөн жок")
    }

    private var verdictColor: Color {
        if item.didFail { return .secondary }
        if item.blocked { return Theme.accentGreen }
        if item.isControl { return .secondary }
        return Theme.statusRed
    }
}

// MARK: - Speed Test Bar Row
struct SpeedTestBarRow: View {
    let item: SpeedTestItem
    let isFastest: Bool
    @ObservedObject var l10n = LocalizationManager.shared
    
    var body: some View {
        HStack(spacing: 10) {
            CustomCountryFlag(code: item.id, width: 20, height: 14)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if isFastest {
                        Text(tr("Лучший", "Fastest", "Эң мыкты"))
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.accentGreen)
                            .foregroundColor(Theme.onAccent)
                            .clipShape(Capsule())
                    }
                }
                Text(item.server)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 4)
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 6)
                    
                    if item.latencyMs > 0 {
                        let pct = min(1.0, CGFloat(item.latencyMs) / 300.0)
                        Capsule()
                            .fill(speedColor(item.latencyMs))
                            .frame(width: max(8, geo.size.width * (1.0 - pct * 0.7)), height: 6)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 80, height: 12)
            
            // Latency Text
            Text(item.latencyMs >= 0 ? "\(item.latencyMs) ms" : (tr("Ошибка", "Error", "Ката")))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(item.latencyMs >= 0 ? speedColor(item.latencyMs) : .secondary)
                .frame(width: 55, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
    
    private func speedColor(_ ms: Int) -> Color {
        if ms < 30 { return Theme.accentGreen }
        if ms < 90 { return Theme.statusBlue }
        if ms < 160 { return Theme.statusOrange }
        return Theme.statusRed
    }
}
