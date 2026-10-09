import SwiftUI
import AppKit

/// Встроенный VPN: одна ссылка подписки и одна кнопка.
///
/// Остальная вкладка рассчитана на человека, который сам ставит и запускает
/// Xray или sing-box. Эта карточка - для всех остальных: ядро своё, каналы,
/// автовыбор и их порядок приезжают с сервера по подписке и обновляются сами.
struct EmbeddedVPNCard: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var subscriptionInput: String = ""
    @State private var editingSubscription = false

    private var core: VPNCoreStatus { manager.vpnCore }
    private var connected: Bool { core.isUp && manager.vpnActive }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if core.proxyOrphaned ?? false { orphanWarning }
            if !core.hasSubscription || editingSubscription { subscriptionField } else { details }
        }
        .padding(14)
        .background(Theme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(connected ? Theme.accentGreen.opacity(0.45) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .onAppear { manager.refreshVPNCore() }
    }

    // MARK: - Шапка: состояние и главная кнопка
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(connected ? Theme.accentGreen.opacity(0.15) : Color.primary.opacity(0.05))
                    .frame(width: 44, height: 44)
                Image(systemName: connected ? "lock.shield.fill" : "shield.slash")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(connected ? Theme.accentGreen : .secondary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Встроенный VPN", "Built-in VPN", "Камтылган VPN"))
                    .font(.system(size: 14, weight: .bold))
                Text(statusLine)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if manager.vpnCoreBusy {
                ProgressView().controlSize(.small)
            } else if core.hasSubscription && !editingSubscription {
                Button(connected ? tr("Отключить", "Disconnect", "Ажыратуу") : tr("Подключить", "Connect", "Туташтыруу")) {
                    connected ? manager.disconnectEmbeddedVPN() : manager.connectEmbeddedVPN()
                }
                .buttonStyle(.borderedProminent)
                .tint(connected ? Color.secondary : Theme.accentGreen)
                .controlSize(.regular)
            }
        }
    }

    private var statusLine: String {
        if manager.vpnCoreBusy { return manager.busyMessage.isEmpty ? tr("Подождите…", "Please wait…", "Күтө туруңуз…") : manager.busyMessage }
        if !core.hasSubscription {
            return tr("Вставьте ссылку подписки из бота — каналы настроятся сами.",
                      "Paste the subscription link from the bot — channels configure themselves.", "Боттон жазылуу шилтемесин коюңуз — каналдар өзү жөндөлөт.")
        }
        if connected {
            let node = (core.activeNode ?? "").isEmpty ? tr("автовыбор", "auto", "автотандоо") : (core.activeNode ?? "")
            let delay = (core.activeDelayMs ?? -1) > 0 ? " · " + tr("\(core.activeDelayMs ?? 0) мс", "\(core.activeDelayMs ?? 0) ms", "\(core.activeDelayMs ?? 0) мс") : ""
            return tr("Подключён: \(node)\(delay)", "Connected: \(node)\(delay)", "Туташты: \(node)\(delay)")
        }
        if core.isUp { return tr("Ядро запущено, системный прокси выключен", "Core is running, system proxy is off", "Ядро иштеп жатат, системалык прокси өчүк") }
        return tr("Отключён", "Disconnected", "Ажыратылган")
    }

    // MARK: - Осиротевший прокси
    private var orphanWarning: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.statusOrange)
                .accessibilityHidden(true)
            Text(tr("Системный прокси включён, но VPN-ядро не работает — из-за этого может не открываться ничего.",
                    "The system proxy is on but the VPN core is not running — this can break all connections.", "Системалык прокси күйүк, бирок VPN-ядро иштебей жатат — ушундан улам эч нерсе ачылбай калышы мүмкүн."))
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(tr("Снять прокси", "Remove proxy", "Проксини алып салуу")) { manager.disableAllProxies() }
                .controlSize(.small)
        }
        .padding(10)
        .background(Theme.statusOrange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Ввод подписки
    private var subscriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(tr("http://…/sub/ваш-ключ", "http://…/sub/your-key", "http://…/sub/сиздин-ачкыч"), text: $subscriptionInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .accessibilityLabel(tr("Ссылка подписки", "Subscription link", "Жазылуу шилтемеси"))
                Button(tr("Вставить", "Paste", "Коюу")) {
                    subscriptionInput = NSPasteboard.general.string(forType: .string)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }
                .controlSize(.regular)
                Button(tr("Подключить", "Connect", "Туташтыруу")) {
                    manager.connectEmbeddedVPN(subscription: subscriptionInput)
                    editingSubscription = false
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentGreen)
                .disabled(subscriptionInput.trimmingCharacters(in: .whitespaces).isEmpty || manager.vpnCoreBusy)
            }
            HStack {
                Text(tr("Ссылка — в боте: «Мои ключи». При первом подключении скачается VPN-ядро (около 30 МБ).",
                        "Find the link in the bot under “My keys”. The first connection downloads the VPN core (about 30 MB).", "Шилтеме ботто: «Мои ключи» бөлүмүндө. Биринчи туташууда VPN-ядро жүктөлөт (болжол менен 30 МБ)."))
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if editingSubscription {
                    Button(tr("Отмена", "Cancel", "Жокко чыгаруу")) { editingSubscription = false }.controlSize(.small)
                }
            }
        }
    }

    // MARK: - Сведения и настройки
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                fact(tr("Подписка", "Subscription", "Жазылуу"), core.subscriptionHost ?? "—")
                fact(tr("Каналов", "Channels", "Каналдар"), "\((core.nodes ?? []).count)")
                fact(tr("Профиль", "Profile", "Профиль"), profileAge)
                Spacer()
                Button(tr("Обновить", "Refresh", "Жаңыртуу")) { manager.updateEmbeddedVPNProfile() }
                    .controlSize(.small).disabled(manager.vpnCoreBusy)
                Button(tr("Сменить ссылку", "Change link", "Шилтемени алмаштыруу")) { subscriptionInput = ""; editingSubscription = true }
                    .controlSize(.small).disabled(manager.vpnCoreBusy || connected)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Picker(tr("Имена сайтов внутри VPN", "Site names inside the VPN", "VPN ичиндеги сайттардын аттары"), selection: Binding(
                    get: { core.dnsMode == "system" ? "system" : "tunnel" },
                    set: { manager.setEmbeddedVPNDNSMode($0) }
                )) {
                    Text(tr("Через туннель", "Through the tunnel", "Туннель аркылуу")).tag("tunnel")
                    Text(tr("Через фильтр Cerberus", "Through the Cerberus filter", "Cerberus чыпкасы аркылуу")).tag("system")
                }
                .pickerStyle(.segmented)
                .disabled(manager.vpnCoreBusy)

                Text(core.dnsMode == "system"
                     ? tr("Реклама режется и внутри VPN, но провайдер видит, какие сайты вы открываете.",
                          "Ads are blocked inside the VPN too, but your provider sees which sites you open.", "Жарнама VPN ичинде да кесилет, бирок провайдер сиз кайсы сайттарды ачып жатканыңызды көрөт.")
                     : tr("Провайдер не видит, какие сайты вы открываете. Фильтр рекламы на трафик через VPN не действует.",
                          "Your provider cannot see which sites you open. The ad filter does not apply to VPN traffic.", "Провайдер сиз кайсы сайттарды ачып жатканыңызды көрбөйт. Жарнама чыпкасы VPN аркылуу өткөн трафикке иштебейт."))
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary)
            Text(value).font(.system(size: 12, weight: .medium)).lineLimit(1)
        }
    }

    private var profileAge: String {
        let age = core.profileAgeSec ?? -1
        if age < 0 { return "—" }
        if age < 3600 { return tr("\(max(1, age / 60)) мин назад", "\(max(1, age / 60)) min ago", "\(max(1, age / 60)) мүн мурун") }
        if age < 86400 { return tr("\(age / 3600) ч назад", "\(age / 3600) h ago", "\(age / 3600) саат мурун") }
        return tr("\(age / 86400) дн назад", "\(age / 86400) d ago", "\(age / 86400) күн мурун")
    }
}
