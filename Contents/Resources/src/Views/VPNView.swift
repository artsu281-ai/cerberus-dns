import SwiftUI
import AppKit

struct VPNView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject var l10n = LocalizationManager.shared
    
    @State private var selectedFilterCategory: Int = 0 // 0: All, 1: VLESS, 2: SS/Trojan, 3: Anycast
    @State private var newProxyDomainInput: String = ""
    @State private var newDirectDomainInput: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("VPN, VLESS и Маршрутизация", "VPN, VLESS & Traffic Routing", "VPN, VLESS жана маршруттоо"))
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                    
                    Text(tr("Поддержка протоколов нового поколения (VLESS REALITY, Shadowsocks, Trojan, Hysteria 2) и гибкое раздельное туннелирование.", "Next-gen protocol support (VLESS REALITY, Shadowsocks, Trojan, Hysteria 2) with split tunneling.", "Жаңы муундагы протоколдорду (VLESS REALITY, Shadowsocks, Trojan, Hysteria 2) колдоо жана ийкемдүү бөлүнгөн туннелдөө."))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // MARK: - Встроенный VPN (ядро и подписка внутри приложения)
                EmbeddedVPNCard(manager: manager)

                // MARK: - Sub-Tab Navigation Bar (Consistent Segmented Style)
                HStack(spacing: 8) {
                    VPNSubTabButton(
                        title: tr("Серверы и узлы", "Servers & Nodes", "Серверлер жана түйүндөр"),
                        icon: "network",
                        count: allNodes.count,
                        isSelected: manager.vpnSubTab == 0
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { manager.vpnSubTab = 0 }
                    }
                    
                    VPNSubTabButton(
                        title: tr("Маршрутизация", "Traffic Routing", "Маршруттоо"),
                        icon: "arrow.triangle.branch",
                        count: nil,
                        isSelected: manager.vpnSubTab == 1
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { manager.vpnSubTab = 1 }
                    }
                    
                    VPNSubTabButton(
                        title: tr("Защита", "Security", "Коргоо"),
                        icon: "shield.lefthalf.filled",
                        count: nil,
                        isSelected: manager.vpnSubTab == 2
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { manager.vpnSubTab = 2 }
                    }
                }
                .padding(6)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                
                // MARK: - Sub-Tab Contents
                if manager.vpnSubTab == 0 {
                    serversAndNodesTab
                } else if manager.vpnSubTab == 1 {
                    trafficRoutingTab
                } else {
                    antiDpiAndSecurityTab
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .sheet(isPresented: $manager.showAddNodeSheet) {
            AddNodeSheet(manager: manager) {
                manager.showAddNodeSheet = false
            }
        }
        .onAppear {
            if manager.ipInfo == nil {
                manager.fetchIPInfo()
            }
        }
    }
    
    // MARK: - Sub-Tab 0: Servers & Nodes View
    private var serversAndNodesTab: some View {
        VStack(spacing: 14) {
            // Hero Connection Card
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(manager.vpnActive ? Theme.accentGreen.opacity(0.15) : Color.primary.opacity(0.05))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: manager.vpnActive ? "lock.shield.fill" : "lock.slash")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(manager.vpnActive ? Theme.accentGreen : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(manager.vpnActive ? Theme.accentGreen : Color.secondary)
                            .frame(width: 7, height: 7)
                        
                        Text(manager.vpnActive ?
                             (tr("Туннель активен", "Tunnel Active", "Туннель активдүү")) :
                             (tr("Прямое подключение", "Direct Connection", "Түз туташуу")))
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 6) {
                        if manager.vpnActive {
                            CustomCountryFlag(code: manager.activeNode?.country ?? "WW", width: 16, height: 11)
                        }
                        Text(activeNodeSummary)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { manager.vpnActive },
                    set: { _ in
                        if manager.vpnActive {
                            manager.disableAllProxies()
                        } else {
                            if let active = manager.activeNode, active.isOnline {
                                manager.connectToVPNNode(active)
                            } else if let custom = manager.customNodes.first {
                                manager.connectToVPNNode(custom)
                            } else if let first = manager.availableNodes.first(where: { $0.isOnline }) {
                                manager.connectToVPNNode(first)
                            }
                        }
                    }
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
            
            // Server List Bento Card
            VStack(alignment: .leading, spacing: 12) {
                // Row 1: Header + Action Buttons (No Wrapping!)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(tr("Серверы и узлы", "Servers & Nodes", "Серверлер жана түйүндөр"))
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                            
                            Text("\(allNodes.count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.06))
                                .foregroundColor(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    // Action Buttons (Strict Non-Wrapping)
                    Button(action: {
                        _ = manager.importFromClipboard()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text(tr("Вставить ссылку", "Paste Link", "Шилтемени кыстаруу"))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(tr("Импортировать vless://, ss://, trojan:// из буфера", "Import proxy link from clipboard", "Буферден vless://, ss://, trojan:// импорттоо"))
                    
                    Button(action: {
                        manager.showAddNodeSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text(tr("Добавить узел", "Add Node", "Түйүн кошуу"))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Theme.accent)
                        .foregroundColor(Theme.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { manager.benchmarkVPNNodes() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Проверить узлы заново", "Re-test the nodes", "Түйүндөрдү кайра текшерүү"))
                    .disabled(manager.isCheckingNodes)
                    .help(tr("Замерить пинг до серверов", "Benchmark node latency", "Серверлерге чейинки пингди өлчөө"))
                }
                
                // Row 2: Filter Tabs Strip (Spacious, Equal Width & Centered)
                HStack(spacing: 8) {
                    NodeFilterTabButton(title: tr("Все узлы", "All Nodes", "Бардык түйүндөр"), isSelected: selectedFilterCategory == 0) {
                        selectedFilterCategory = 0
                    }
                    NodeFilterTabButton(title: "VLESS REALITY", isSelected: selectedFilterCategory == 1) {
                        selectedFilterCategory = 1
                    }
                    NodeFilterTabButton(title: "Shadowsocks / Trojan", isSelected: selectedFilterCategory == 2) {
                        selectedFilterCategory = 2
                    }
                    NodeFilterTabButton(title: tr("Публичные DNS", "Public DNS", "Коомдук DNS"), isSelected: selectedFilterCategory == 3) {
                        selectedFilterCategory = 3
                    }
                }
                .padding(6)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                
                // Nodes List
                let nodes = filteredNodes
                if nodes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "network.badge.shield.half.filled")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text(tr("В этой категории нет узлов. Добавьте свой VLESS или Shadowsocks сервер.", "No nodes in this category. Add a custom VLESS or Shadowsocks server.", "Бул категорияда түйүндөр жок. Өзүңүздүн VLESS же Shadowsocks серверин кошуңуз."))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    VStack(spacing: 6) {
                        ForEach(nodes) { node in
                            AdvancedVPNNodeRow(
                                node: node,
                                isConnected: manager.vpnActive && manager.activeNodeId == node.id,
                                onConnect: { manager.connectToVPNNode(node) },
                                onDelete: node.isCustom ? { manager.deleteCustomNode(node.id) } : nil
                            )
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
    
    // MARK: - Sub-Tab 1: Traffic Routing View
    private var trafficRoutingTab: some View {
        VStack(spacing: 14) {
          // Раздел настраивает то, чего приложение пока не делает.
          // Списки сохраняются и пригодятся, когда механизм появится,
          // но обещать разделение трафика сейчас нельзя.
          if !manager.routingIsEnforced {
              HStack(alignment: .top, spacing: 10) {
                  Image(systemName: "wrench.and.screwdriver.fill")
                      .font(.system(size: 14, weight: .semibold))
                      .foregroundColor(Theme.statusOrange)
                      .frame(width: 18)
                  VStack(alignment: .leading, spacing: 3) {
                      Text(tr("Разделение трафика пока не выполняется", "Traffic splitting is not enforced yet", "Трафикти бөлүү азырынча аткарылбайт"))
                          .font(.system(size: 12.5, weight: .bold))
                      Text(tr("Системный прокси в macOS задаётся целиком, без разбора по доменам: для этого нужен PAC-файл или сетевое расширение. Выбранный режим и списки сохраняются, но на маршрут трафика сейчас не влияют.", "The system proxy in macOS is set wholesale, with no per-domain rules: that needs a PAC file or a network extension. The selected mode and lists are saved, but they do not affect routing yet.", "macOS'тогу системалык прокси домендерге бөлүнбөй, толугу менен коюлат: бул үчүн PAC-файл же тармак кеңейтүүсү керек. Тандалган режим жана тизмелер сакталат, бирок азыр трафиктин маршрутуна таасир этпейт."))
                          .font(.system(size: 11))
                          .foregroundColor(.secondary)
                          .fixedSize(horizontal: false, vertical: true)
                  }
                  Spacer(minLength: 0)
              }
              .padding(12)
              .background(Theme.statusOrange.opacity(0.10))
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              .overlay(
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .stroke(Theme.statusOrange.opacity(0.3), lineWidth: 1)
              )
          }
            // Routing Modes Bento Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.accent.opacity(0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: manager.routingMode.iconName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Режим маршрутизации трафика", "Traffic Routing Mode", "Трафикти маршруттоо режими"))
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        Text(manager.routingMode.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.accent)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                
                // 4-Way Routing Mode Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(TrafficRoutingMode.allCases) { mode in
                        Button(action: {
                            manager.routingMode = mode
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: mode.iconName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(manager.routingMode == mode ? Theme.accent : .secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.title)
                                        .font(.system(size: 12, weight: manager.routingMode == mode ? .bold : .medium))
                                        .foregroundColor(manager.routingMode == mode ? .primary : .secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                if manager.routingMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.accent)
                                }
                            }
                            .padding(12)
                            .background(manager.routingMode == mode ? Theme.accent.opacity(0.1) : Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(manager.routingMode == mode ? Theme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(manager.routingMode.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            .padding(14)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            
            // Split Tunneling Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.statusBlue.opacity(0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.statusBlue)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Раздельное туннелирование (Split Tunneling)", "Split Tunneling by Domain", "Бөлүнгөн туннелдөө (Split Tunneling)"))
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        Text(tr("Списки доменов, которые всегда идут через прокси или всегда напрямую без VPN.", "Domain rules forced through proxy vs direct ISP network.", "Ар дайым прокси аркылуу же ар дайым VPN'сиз түз өтүүчү домендердин тизмелери."))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                
                // Two Columns: Force Proxy vs Force Direct
                HStack(alignment: .top, spacing: 12) {
                    // Column 1: Always Proxy
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle().fill(Theme.accent).frame(width: 6, height: 6)
                            Text(tr("Всегда через прокси", "Force Proxy", "Ар дайым прокси аркылуу"))
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                            Spacer()
                            Text("\(manager.forceProxyDomains.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            TextField("youtube.com", text: $newProxyDomainInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 11, design: .monospaced))
                            
                            Button(action: {
                                manager.addForceProxyDomain(newProxyDomainInput)
                                newProxyDomainInput = ""
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .frame(width: 22, height: 22)
                                    .background(Theme.accent)
                                    .foregroundColor(Theme.onAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tr("Добавить домен", "Add a domain", "Домен кошуу"))
                            .disabled(newProxyDomainInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        
                        VStack(spacing: 4) {
                            ForEach(manager.forceProxyDomains.prefix(8), id: \.self) { dom in
                                HStack {
                                    Text(dom).font(.system(size: 11, design: .monospaced)).lineLimit(1)
                                    Spacer()
                                    Button(action: { manager.removeForceProxyDomain(dom) }) {
                                        Image(systemName: "xmark").font(.system(size: 9)).foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(tr("Удалить из списка", "Remove from the list", "Тизмеден жок кылуу"))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    // Column 2: Always Direct (Banks / Gosuslugi)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle().fill(Theme.statusGreen).frame(width: 6, height: 6)
                            Text(tr("Всегда напрямую (Банки/РФ)", "Force Direct (Banks/Gov)", "Ар дайым түз (Банктар/РФ)"))
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                            Spacer()
                            Text("\(manager.forceDirectDomains.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            TextField("gosuslugi.ru", text: $newDirectDomainInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 11, design: .monospaced))
                            
                            Button(action: {
                                manager.addForceDirectDomain(newDirectDomainInput)
                                newDirectDomainInput = ""
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .frame(width: 22, height: 22)
                                    .background(Theme.statusGreen)
                                    .foregroundColor(Theme.readableForeground(on: Theme.statusGreen))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tr("Добавить домен", "Add a domain", "Домен кошуу"))
                            .disabled(newDirectDomainInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        
                        VStack(spacing: 4) {
                            ForEach(manager.forceDirectDomains.prefix(8), id: \.self) { dom in
                                HStack {
                                    Text(dom).font(.system(size: 11, design: .monospaced)).lineLimit(1)
                                    Spacer()
                                    Button(action: { manager.removeForceDirectDomain(dom) }) {
                                        Image(systemName: "xmark").font(.system(size: 9)).foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(tr("Удалить из списка", "Remove from the list", "Тизмеден жок кылуу"))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    
    // MARK: - Sub-Tab 2: Security View
    private var antiDpiAndSecurityTab: some View {
        VStack(spacing: 14) {
            // Переключатели фрагментации TLS и маскировки SNI убраны: они только
            // сохранялись в настройки и ни на что не влияли, а обещали защиту.
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Подключение", "Connection", "Туташуу"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: L("vpn.failover.title"),
                        subtitle: L("vpn.failover.on"),
                        isOn: $manager.autoFailoverEnabled
                    )
                }
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            
            // Public IP & Location Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L("vpn.ip.title"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: { manager.fetchIPInfo() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text(L("vpn.ip.refresh"))
                                .lineLimit(1)
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("IP:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(manager.ipInfo?.ip ?? "—")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                    }
                    
                    Divider().frame(height: 24)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Локация:", "Location:", "Жайгашкан жери:"))
                             .font(.system(size: 10))
                             .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            CustomCountryFlag(code: manager.ipInfo?.country ?? "WW", width: 18, height: 12)
                            Text("\(manager.ipInfo?.city ?? "—"), \(manager.ipInfo?.country ?? "")")
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                        }
                    }
                    
                    Divider().frame(height: 24)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Провайдер:", "ISP:", "Провайдер:"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(manager.ipInfo?.org ?? "—")
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    
    private var allNodes: [VPNNode] {
        return manager.customNodes + manager.availableNodes
    }
    
    private var filteredNodes: [VPNNode] {
        let all = allNodes
        switch selectedFilterCategory {
        case 1: // VLESS
            return all.filter { $0.protocolType == "vless" }
        case 2: // SS & Trojan & HY2
            return all.filter { $0.protocolType == "shadowsocks" || $0.protocolType == "trojan" || $0.protocolType == "hysteria2" || $0.protocolType == "socks5" }
        case 3: // Публичные резолверы
            // Раньше фильтр перечислял идентификаторы поимённо, поэтому
            // добавленный в движок узел в него не попадал.
            return all.filter { $0.kind == .dns }
        default:
            return all
        }
    }
    
    private var activeNodeSummary: String {
        if !manager.vpnActive { return tr("Прямое подключение к сети", "Direct network connection", "Тармакка түз туташуу") }
        if let node = allNodes.first(where: { $0.id == manager.activeNodeId }) {
            return "\(node.name) [\(node.kindBadge)]"
        }
        return "Encrypted VLESS / Proxy Tunnel Active"
    }
}

// MARK: - VPN Sub-Tab Button Component
struct VPNSubTabButton: View {
    let title: String
    let icon: String
    let count: Int?
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
                    .fixedSize(horizontal: true, vertical: false)
                
                if let c = count {
                    Text("\(c)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Theme.onAccent.opacity(0.25) : Color.primary.opacity(0.06))
                        .foregroundColor(isSelected ? Theme.onAccent : .secondary)
                        .clipShape(Capsule())
                }
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

// MARK: - Advanced VPN Node Row
struct AdvancedVPNNodeRow: View {
    let node: VPNNode
    let isConnected: Bool
    let onConnect: () -> Void
    let onDelete: (() -> Void)?
    
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            CustomCountryFlag(code: node.country.isEmpty ? node.id : node.country, width: 22, height: 15)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(node.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    
                    // Protocol Badge
                    // Бейдж брался из `protocolType` и подписывал публичные
                    // DNS-резолверы как SOCKS5/HTTP-прокси. `kindBadge` смотрит
                    // на порт и различает резолвер и настоящий туннель.
                    Text(node.kindBadge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(nodeBadgeColor(node).opacity(0.15))
                        .foregroundColor(nodeBadgeColor(node))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    
                    if isConnected {
                        Text(tr("Активен", "Active", "Активдүү"))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.accentGreen)
                            .foregroundColor(Theme.onAccent)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 6) {
                    Text("\(node.host):\(node.port)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let sni = node.sni, !sni.isEmpty {
                        Text("• SNI: \(sni)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Latency Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(node.isOnline ? pingColor(node.latencyMs) : Color.red)
                    .frame(width: 5, height: 5)
                
                Text(node.isOnline && node.latencyMs >= 0 ? "\(node.latencyMs) ms" : (tr("Готов", "Ready", "Даяр")))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(node.isOnline && node.latencyMs >= 0 ? pingColor(node.latencyMs) : .secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.04))
            .clipShape(Capsule())
            
            // Delete Action for custom nodes
            if let del = onDelete {
                Button(action: del) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Удалить узел", "Remove the node", "Түйүндү жок кылуу"))
                .help(tr("Удалить узел", "Delete node", "Түйүндү жок кылуу"))
            }
            
            // Connect Button
            Button(action: onConnect) {
                Text(isConnected ?
                     (tr("Активен", "Active", "Активдүү")) :
                     (tr("Подключить", "Connect", "Туташтыруу")))
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isConnected ? Theme.accentGreen.opacity(0.15) : Color.primary.opacity(0.06))
                    .foregroundColor(isConnected ? Theme.accentGreen : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isConnected ? Color.accentColor.opacity(0.04) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { h in isHovered = h }
    }
    
    private func pingColor(_ ms: Int) -> Color {
        if ms < 0 { return Theme.statusBlue }
        if ms < 40 { return Theme.accentGreen }
        if ms < 100 { return Theme.statusBlue }
        if ms < 180 { return Theme.statusOrange }
        return Theme.statusRed
    }
    
    private func nodeBadgeColor(_ node: VPNNode) -> Color {
        if node.kind == .dns { return Theme.statusCyan }
        switch node.protocolType.lowercased() {
        case "vless": return Color.purple
        case "shadowsocks": return Color.blue
        case "trojan": return Color.orange
        case "hysteria2": return Color.pink
        default: return Theme.accent
        }
    }
}

// MARK: - Node Filter Tab Button
struct NodeFilterTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.accent : Color.primary.opacity(0.05))
                .foregroundColor(isSelected ? Theme.onAccent : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
