import SwiftUI

struct AddNodeSheet: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject var l10n = LocalizationManager.shared
    let onDismiss: () -> Void
    
    @State private var selectedProtocol: ProxyProtocol = .vless
    @State private var rawShareLink: String = ""
    @State private var linkParseError: String? = nil
    
    // Manual Form Fields
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "443"
    @State private var countryCode: String = "DE"
    
    // VLESS / REALITY fields
    @State private var uuid: String = ""
    @State private var sni: String = "apple.com"
    @State private var publicKey: String = ""
    @State private var shortId: String = ""
    @State private var flow: String = "xtls-rprx-vision"
    @State private var transport: String = "tcp"
    
    // Shadowsocks / Trojan / Hysteria 2 fields
    @State private var password: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "plus.shield.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Добавить узел (VLESS / Proxy)", "Add Node (VLESS / Proxy)", "Түйүн кошуу (VLESS / Proxy)"))
                        .font(.system(size: 15, weight: .bold))
                    Text(tr("Импортируйте ссылку конфигурации или введите параметры вручную.", "Import share link or configure node parameters manually.", "Конфигурация шилтемесин импорттоңуз же параметрлерди кол менен киргизиңиз."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Закрыть", "Close", "Жабуу"))
            }
            .padding(16)
            
            Divider().opacity(0.2)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Quick Import from Share Link
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Быстрый импорт по ссылке:", "Quick Import via Link:", "Шилтеме аркылуу тез импорт:"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 8) {
                            TextField("vless://uuid@host:443?security=reality&sni=...#Name", text: $rawShareLink)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 11.5, design: .monospaced))
                            
                            Button(action: parseLink) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text(tr("Распознать", "Parse", "Таануу"))
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .frame(height: 24)
                                .background(Theme.accent)
                                .foregroundColor(Theme.onAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(rawShareLink.trimmingCharacters(in: .whitespaces).isEmpty)
                            
                            Button(action: {
                                if let clip = NSPasteboard.general.string(forType: .string) {
                                    rawShareLink = clip
                                    parseLink()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text(tr("Вставить", "Paste", "Коюу"))
                                }
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if let err = linkParseError {
                            Text(err)
                                .font(.system(size: 10.5))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(12)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // 2. Protocol Selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Протокол узла:", "Protocol:", "Түйүндүн протоколу:"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Picker("", selection: $selectedProtocol) {
                            ForEach(ProxyProtocol.allCases) { proto in
                                Text(proto.title).tag(proto)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // 3. Common Server Fields
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tr("Название узла:", "Node Name:", "Түйүндүн аталышы:"))
                                    .font(.system(size: 11, weight: .semibold))
                                TextField("Frankfurt High-Speed VLESS", text: $name)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 12))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tr("Страна / Флаг:", "Country:", "Өлкө / Желек:"))
                                    .font(.system(size: 11, weight: .semibold))
                                TextField("DE / NL / US", text: $countryCode)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(width: 90)
                            }
                        }
                        
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tr("Сервер (IP / Host):", "Server Host:", "Сервер (IP / Host):"))
                                    .font(.system(size: 11, weight: .semibold))
                                TextField("198.51.100.1 or node.example.com", text: $host)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 12, design: .monospaced))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tr("Порт:", "Port:", "Порт:"))
                                    .font(.system(size: 11, weight: .semibold))
                                TextField("443", text: $port)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(width: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .stroke(isPortValid ? Color.clear : Theme.statusRed.opacity(0.6), lineWidth: 1)
                                    )
                            }

                            // Проблему с портом видно сразу, а не при попытке
                            // подключиться к уже сохранённому узлу.
                            if let hint = portHint {
                                Text(hint)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(isPortValid ? Theme.statusOrange : Theme.statusRed)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    
                    // 4. Protocol-Specific Detailed Fields
                    if selectedProtocol == .vless {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VLESS REALITY & Vision")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.accent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("UUID (Client ID):")
                                    .font(.system(size: 11, weight: .semibold))
                                TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $uuid)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tr("Маскировка SNI:", "SNI Mask:", "SNI маскировкасы:"))
                                        .font(.system(size: 11, weight: .semibold))
                                    TextField("apple.com or yahoo.com", text: $sni)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.system(size: 11.5))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Flow (Vision):")
                                        .font(.system(size: 11, weight: .semibold))
                                    TextField("xtls-rprx-vision", text: $flow)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.system(size: 11.5, design: .monospaced))
                                }
                            }
                            
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Public Key (REALITY):")
                                        .font(.system(size: 11, weight: .semibold))
                                    TextField("Base64 Public Key", text: $publicKey)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.system(size: 11, design: .monospaced))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Short ID:")
                                        .font(.system(size: 11, weight: .semibold))
                                    TextField("Short Hex", text: $shortId)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(width: 90)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else if selectedProtocol == .shadowsocks || selectedProtocol == .trojan || selectedProtocol == .hysteria2 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(selectedProtocol.title) Credentials")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.accent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tr("Пароль / Secret Key:", "Password / Secret:", "Сырсөз / Secret Key:"))
                                    .font(.system(size: 11, weight: .semibold))
                                SecureField("••••••••••••••••", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11.5, design: .monospaced))
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(16)
            }
            
            Divider().opacity(0.2)
            
            // Footer Action Buttons
            HStack {
                Button(tr("Отмена", "Cancel", "Жокко чыгаруу"), action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: saveNode) {
                    Text(tr("Сохранить узел", "Save Node", "Түйүндү сактоо"))
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 16)
                        .frame(height: 28)
                        .background(isSaveDisabled ? Color.secondary.opacity(0.2) : Theme.accent)
                        .foregroundColor(isSaveDisabled ? .secondary : Theme.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaveDisabled)
                .opacity(isSaveDisabled ? 0.5 : 1)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 500)
    }
    
    /// Порт проверяется здесь, а не при подключении.
    ///
    /// Раньше сохранить можно было узел с пустым или буквенным портом: ошибка
    /// всплывала только в момент подключения, когда узел уже лежал в списке.
    private var portNumber: Int? {
        Int(port.trimmingCharacters(in: .whitespaces))
    }

    private var isPortValid: Bool {
        guard let p = portNumber else { return false }
        return p > 0 && p < 65536
    }

    private var isSaveDisabled: Bool {
        host.trimmingCharacters(in: .whitespaces).isEmpty
            || name.trimmingCharacters(in: .whitespaces).isEmpty
            || !isPortValid
    }

    private var portHint: String? {
        let raw = port.trimmingCharacters(in: .whitespaces)
        if raw.isEmpty { return tr("Укажите порт", "Enter a port", "Портту көрсөтүңүз") }
        guard let p = portNumber else {
            return tr("Порт — это число", "The port must be a number", "Порт сан болушу керек")
        }
        guard p > 0 && p < 65536 else {
            return tr("Порт вне диапазона 1–65535", "Port must be between 1 and 65535", "Порт 1–65535 аралыгынан тышкары")
        }
        if p == 53 {
            return tr("Порт 53 — это DNS, узел будет применён как DNS-профиль", "Port 53 is DNS; this node will be applied as a DNS profile", "53-порт — бул DNS, түйүн DNS-профиль катары колдонулат")
        }
        return nil
    }
    
    private func parseLink() {
        linkParseError = nil
        if let node = manager.parseProxyLink(rawShareLink) {
            name = node.name
            host = node.host
            port = node.port
            countryCode = node.country
            if let p = ProxyProtocol(rawValue: node.protocolType) {
                selectedProtocol = p
            }
            uuid = node.uuid ?? ""
            sni = node.sni ?? "apple.com"
            publicKey = node.publicKey ?? ""
            shortId = node.shortId ?? ""
            flow = node.flow ?? "xtls-rprx-vision"
            password = node.password ?? ""
            transport = node.transport ?? "tcp"
        } else {
            linkParseError = tr("Не удалось распознать ссылку. Поддерживаются vless://, ss://, trojan://, hysteria2://", "Failed to parse share link. Formats: vless://, ss://, trojan://, hysteria2://", "Шилтемени таануу мүмкүн болгон жок. Колдоого алынат: vless://, ss://, trojan://, hysteria2://")
        }
    }
    
    private func saveNode() {
        let cleanCountry = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let node = VPNNode(
            id: "\(selectedProtocol.rawValue)_\(UUID().uuidString.prefix(8))",
            name: name.trimmingCharacters(in: .whitespaces),
            country: cleanCountry.isEmpty ? "DE" : cleanCountry,
            flag: "🌐",
            host: host.trimmingCharacters(in: .whitespaces),
            port: port.trimmingCharacters(in: .whitespaces),
            protocolType: selectedProtocol.rawValue,
            isRecommended: false,
            latencyMs: -1,
            isOnline: true,
            uuid: uuid.isEmpty ? nil : uuid,
            password: password.isEmpty ? nil : password,
            security: selectedProtocol == .vless ? "reality" : nil,
            sni: sni.isEmpty ? nil : sni,
            publicKey: publicKey.isEmpty ? nil : publicKey,
            shortId: shortId.isEmpty ? nil : shortId,
            flow: flow.isEmpty ? nil : flow,
            transport: transport,
            isCustom: true
        )
        manager.addCustomNode(node)
        onDismiss()
    }
}
