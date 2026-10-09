import SwiftUI

struct MenuBarPopoverView: View {
    // Без наблюдения за менеджером языка попап не перерисовывался при
    // переключении RU/EN — он живёт в отдельном NSHostingController.
    @ObservedObject private var l10n = LocalizationManager.shared
    @ObservedObject private var themeMgr = ThemeManager.shared

    @ObservedObject var manager: DNSManager
    let onOpenMainWindow: () -> Void
    let onQuit: () -> Void
    
    @State private var selectedSection: Int = 0 // 0: DNS, 1: VPN
    
    var body: some View {
        VStack(spacing: 12) {
            // MARK: - Header Bar
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: manager.isProtected ? "shield.fill" : "shield.slash.fill")
                        .foregroundColor(manager.isProtected ? Theme.statusGreen : .secondary)
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("Cerberus DNS")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    
                    if manager.vpnActive {
                        Text("VPN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Theme.statusBlue.opacity(0.2))
                            .foregroundColor(Theme.statusBlue)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                Button(action: onOpenMainWindow) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Открыть главное окно", "Open the main window", "Башкы терезени ачуу"))
                .help(tr("Развернуть главное окно", "Open the main window", "Башкы терезени жайып ачуу"))
            }
            
            // MARK: - Pause Banner (if active)
            if manager.isPaused {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.statusOrange)
                    Text(tr("Пауза: \(manager.formattedPauseRemaining)", "Paused: \(manager.formattedPauseRemaining)", "Тыным: \(manager.formattedPauseRemaining)"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Spacer()
                    Button(tr("Включить", "Resume", "Күйгүзүү"), action: { manager.resumeProtection() })
                        .font(.system(size: 10, weight: .bold))
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.statusGreen)
                        .controlSize(.mini)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.statusOrange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            // MARK: - Hero Toggle Card
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(manager.isProtected ? Theme.greenGradient : Theme.darkBezelGradient)
                        .frame(width: 38, height: 38)
                        .shadow(color: manager.isProtected ? Theme.statusGreen.opacity(0.35) : Color.clear, radius: 5)
                    
                    Image(systemName: manager.isProtected ? "shield.fill" : "shield.slash.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.onAccent)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(manager.isProtectionBypassed
                         ? tr("Не действует", "Not in effect", "Иштебей жатат")
                         : (manager.isProtected ? tr("Защита активна", "Protection active", "Коргоо активдүү")
                            : (manager.isPaused ? tr("На паузе", "Paused", "Тынымда") : tr("Защита отключена", "Protection off", "Коргоо өчүрүлгөн"))))
                        .font(.system(size: 13, weight: .bold))
                    
                    Text(manager.vpnActive ? "VPN: \(activeNodeName)" : manager.currentProfile.title)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { manager.isProtected },
                    set: { _ in manager.toggleProtection() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: Theme.statusGreen))
                .scaleEffect(0.85)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // MARK: - Segmented Mode Switcher (DNS vs VPN)
            HStack(spacing: 2) {
                Button(action: { selectedSection = 0 }) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkerboard")
                            .font(.system(size: 10))
                        Text(tr("Профили DNS", "DNS profiles", "DNS профилдери"))
                            .font(.system(size: 11, weight: selectedSection == 0 ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4.5)
                    .background(selectedSection == 0 ? Theme.controlBackground : Color.clear)
                    .foregroundColor(selectedSection == 0 ? .primary : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .shadow(color: selectedSection == 0 ? Color.black.opacity(0.08) : Color.clear, radius: 2)
                }
                .buttonStyle(.plain)
                
                Button(action: { selectedSection = 1 }) {
                    HStack(spacing: 4) {
                        Image(systemName: "network.badge.shield.half.filled")
                            .font(.system(size: 10))
                        Text(tr("VPN и прокси", "VPN & proxy", "VPN жана прокси"))
                            .font(.system(size: 11, weight: selectedSection == 1 ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4.5)
                    .background(selectedSection == 1 ? Theme.controlBackground : Color.clear)
                    .foregroundColor(selectedSection == 1 ? .primary : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .shadow(color: selectedSection == 1 ? Color.black.opacity(0.08) : Color.clear, radius: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(2)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            
            // MARK: - Section 0: DNS Profiles & Quick Pause
            if selectedSection == 0 {
                VStack(spacing: 8) {
                    // Quick Pause Bar
                    if manager.isProtected && !manager.isPaused {
                        HStack(spacing: 5) {
                            Text(tr("Пауза:", "Pause:", "Тыным:"))
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach([PauseDuration.min5, PauseDuration.min15, PauseDuration.min30]) { dur in
                                Button(action: { manager.pauseProtection(for: dur) }) {
                                    Text(dur.title)
                                        .font(.system(size: 9.5))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2.5)
                                        .background(Color.primary.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }
                    
                    // Profile Buttons
                    HStack(spacing: 5) {
                        QuickProfileMiniButton(
                            title: "AdGuard",
                            icon: "shield.checkerboard",
                            isSelected: manager.isProtected && manager.currentProfileId == "adguard"
                        ) {
                            if let p = DNSProfile.allProfiles.first(where: { $0.id == "adguard" }) {
                                manager.applyProfile(p)
                            }
                        }
                        
                        QuickProfileMiniButton(
                            title: "dnsmasq",
                            icon: "cpu",
                            isSelected: manager.isProtected && manager.currentProfileId == "local_dnsmasq"
                        ) {
                            if let p = DNSProfile.allProfiles.first(where: { $0.id == "local_dnsmasq" }) {
                                manager.applyProfile(p)
                            }
                        }
                        
                        QuickProfileMiniButton(
                            title: "Cloudflare",
                            icon: "bolt.shield",
                            isSelected: manager.isProtected && manager.currentProfileId == "cloudflare_security"
                        ) {
                            if let p = DNSProfile.allProfiles.first(where: { $0.id == "cloudflare_security" }) {
                                manager.applyProfile(p)
                            }
                        }
                    }
                }
            }
            
            // MARK: - Section 1: VPN & Proxy Nodes List
            if selectedSection == 1 {
                VStack(spacing: 4) {
                    ScrollView {
                        VStack(spacing: 3) {
                            ForEach(manager.allNodes) { node in
                                PopoverVPNNodeRow(
                                    node: node,
                                    isActive: manager.vpnActive && manager.activeNodeId == node.id,
                                    onConnect: {
                                        manager.connectToVPNNode(node)
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 130)
                    
                    if manager.vpnActive {
                        Button(action: { manager.disconnectVPN() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                Text(tr("Отключить VPN", "Disconnect VPN", "VPN'ди ажыратуу"))
                            }
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider().opacity(0.25)
            
            // MARK: - Mini Stats & Bottom Actions
            HStack {
                // Ping Badge
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9.5))
                        .foregroundColor(Theme.statusOrange)
                    Text(manager.currentPingMs >= 0 ? "\(manager.currentPingMs) ms" : "—")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                }
                
                Spacer()
                
                Button(action: { manager.flushDNS() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                        Text(tr("Сброс", "Flush", "Тазалоо"))
                    }
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(tr("Сбросить кэш DNS macOS", "Flush the macOS DNS cache", "macOS DNS кэшин тазалоо"))
                
                Text("•").foregroundColor(.secondary.opacity(0.4))
                
                Button(action: onQuit) {
                    Text(tr("Завершить", "Quit", "Чыгуу"))
                        .font(.system(size: 10.5))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
        }
        .padding(12)
        .frame(width: 300)
        .background(.regularMaterial)
        .preferredColorScheme(themeMgr.appearance.colorScheme)
        .animation(.easeInOut(duration: 0.25), value: themeMgr.appearance)
    }
    
    private var activeNodeName: String {
        manager.allNodes.first(where: { $0.id == manager.activeNodeId })?.name ?? "WARP"
    }
}

// MARK: - Popover VPN Node Row
struct PopoverVPNNodeRow: View {
    let node: VPNNode
    let isActive: Bool
    let onConnect: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 8) {
                // Vector Flag Badge
                CustomCountryFlag(code: node.country, width: 16, height: 11)
                
                // Name
                Text(node.name)
                    .font(.system(size: 11, weight: isActive ? .bold : .medium))
                    .foregroundColor(isActive ? Theme.statusBlue : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Protocol Tag
                Text(node.protocolType.uppercased())
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.06))
                    .foregroundColor(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                
                // Latency
                Text("\(node.latencyMs) ms")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(node.latencyMs < 30 ? Theme.statusGreen : .secondary)
                
                // Active Checkmark
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.statusBlue)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Theme.statusBlue.opacity(0.12) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }
}

struct QuickProfileMiniButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5))
                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5.5)
            .background(isSelected ? Theme.accent : Color.primary.opacity(0.06))
            .foregroundColor(isSelected ? Theme.onAccent : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
