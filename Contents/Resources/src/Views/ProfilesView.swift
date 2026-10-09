import SwiftUI

struct ProfilesView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject var l10n = LocalizationManager.shared
    
    @State private var customIPs: String = ""
    @State private var selectedFilter: Int = 0 // 0: All, 1: Ad-Block, 2: Privacy, 3: Family
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Профили фильтрации DNS", "DNS Profiles & Providers", "DNS чыпкалоо профилдери"))
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                    
                    Text(tr("Готовые конфигурации DNS для блокировки рекламы, защиты от вредоносных сайтов и родительского контроля.", "Pre-configured DNS servers for ad blocking, malware prevention, and family protection.", "Жарнаманы бөгөттөө, зыяндуу сайттардан коргоо жана ата-энелик көзөмөл үчүн даяр DNS конфигурациялары."))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // MARK: - Filter Segmented Bar
                HStack(spacing: 8) {
                    NodeFilterTabButton(
                        title: tr("Все профили", "All Profiles", "Бардык профилдер"),
                        isSelected: selectedFilter == 0
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { selectedFilter = 0 }
                    }
                    
                    NodeFilterTabButton(
                        title: tr("Блокировка рекламы", "Ad-Blocking", "Жарнаманы бөгөттөө"),
                        isSelected: selectedFilter == 1
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { selectedFilter = 1 }
                    }
                    
                    NodeFilterTabButton(
                        title: tr("Приватность", "Privacy", "Купуялык"),
                        isSelected: selectedFilter == 2
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { selectedFilter = 2 }
                    }
                    
                    NodeFilterTabButton(
                        title: tr("Семейные", "Family Safe", "Үй-бүлөлүк"),
                        isSelected: selectedFilter == 3
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { selectedFilter = 3 }
                    }
                }
                .padding(6)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                
                // MARK: - Inset Grouped Profiles List
                VStack(spacing: 6) {
                    ForEach(filteredProfiles) { profile in
                        NativeProfileListRow(
                            profile: profile,
                            isActive: manager.isProtected && manager.currentProfileId == profile.id,
                            onApply: {
                                if profile.id == "custom" {
                                    manager.applyProfile(profile, customServers: customIPs.isEmpty ? manager.customDNSServers : customIPs)
                                } else {
                                    manager.applyProfile(profile)
                                }
                            },
                            customIPBinding: profile.id == "custom" ? $customIPs : nil
                        )
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
        .onAppear {
            customIPs = manager.customDNSServers
        }
    }
    
    private var filteredProfiles: [DNSProfile] {
        switch selectedFilter {
        case 1: // Ad-Blocking
            return DNSProfile.allProfiles.filter { $0.id == "adguard" || $0.id == "local_dnsmasq" || $0.id == "mullvad" }
        case 2: // Privacy
            return DNSProfile.allProfiles.filter { $0.id == "quad9" || $0.id == "local_dnsmasq" || $0.id == "mullvad" }
        case 3: // Family
            return DNSProfile.allProfiles.filter { $0.id == "adguard_family" || $0.id == "cloudflare_family" }
        default:
            return DNSProfile.allProfiles
        }
    }
}

// MARK: - Native Inset Profile List Row (Strict Apple HIG Style)
struct NativeProfileListRow: View {
    let profile: DNSProfile
    let isActive: Bool
    let onApply: () -> Void
    var customIPBinding: Binding<String>? = nil
    
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Profile Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(profile.color.opacity(isActive ? 0.2 : 0.12))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: profileIcon(profile.id))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(profile.color)
                }
                
                // Profile Title & Description
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(profile.badge)
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(profile.color.opacity(0.15))
                            .foregroundColor(profile.color)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .lineLimit(1)
                            .fixedSize()
                        
                        if !profile.servers.isEmpty && profile.id != "custom" {
                            Text("• \(profile.servers.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "")")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Text(profile.description)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 8)
                
                // Action Selector
                if isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.accentGreen)
                        
                        Text(tr("Активен", "Active", "Активдүү"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.accentGreen)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Theme.accentGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Button(action: onApply) {
                        Text(tr("Выбрать", "Select", "Тандоо"))
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(Color.primary.opacity(0.05))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Custom DNS IP input if custom profile
            if profile.id == "custom", let binding = customIPBinding {
                HStack(spacing: 8) {
                    Text(tr("DNS Серверы:", "DNS Servers:", "DNS серверлер:"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("1.1.1.1 1.0.0.1", text: binding)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 11.5, design: .monospaced))
                    
                    Button(action: onApply) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text(tr("Применить", "Apply", "Колдонуу"))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Color.primary.opacity(0.06))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Theme.accentGreen.opacity(0.04) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? Theme.accentGreen.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { h in isHovered = h }
    }
    
    private func profileIcon(_ id: String) -> String {
        switch id {
        case "adguard": return "shield.fill"
        case "local_dnsmasq": return "cpu.fill"
        case "adguard_family": return "person.2.fill"
        case "cloudflare_security": return "bolt.shield.fill"
        case "cloudflare_family": return "figure.2.and.child.holdinghands"
        case "quad9": return "lock.shield.fill"
        case "mullvad": return "eye.slash.fill"
        case "custom": return "slider.horizontal.3"
        default: return "server.rack"
        }
    }
}
