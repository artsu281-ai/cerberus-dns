import SwiftUI

struct FAQView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject private var l10n = LocalizationManager.shared
    @State private var searchQuery: String = ""
    /// Хранится ключ категории, а не подпись: раньше фильтр сравнивал
    /// переведённый текст и после переключения языка переставал совпадать —
    /// список молча становился пустым.
    @State private var selectedCategoryKey: String = "all"
    @State private var expandedItemIds: Set<String> = []
    
    private var categories: [(key: String, title: String)] {
        [("all", tr("Все", "All", "Баары")),
         ("basics", tr("Основы", "Basics", "Негиздер")),
         ("vpn", tr("VPN и Туннели", "VPN & tunnels", "VPN жана туннелдер")),
         ("security", tr("Безопасность", "Security", "Коопсуздук")),
         ("rules", tr("Списки и Правила", "Rules & lists", "Тизмелер жана Эрежелер")),
         ("troubleshooting", tr("Устранение неполадок", "Troubleshooting", "Көйгөйлөрдү оңдоо")),
         ("performance", tr("Производительность", "Performance", "Өндүрүмдүүлүк"))]
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("База знаний и FAQ", "Knowledge base & FAQ", "Билим базасы жана FAQ"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    
                    Text(tr("Ответы на частые вопросы, руководства по безопасности и настройке туннелей.",
                         "Answers to common questions plus guides on security and tunnel setup.", "Көп берилүүчү суроолорго жооптор, коопсуздук жана туннелдерди жөндөө боюнча колдонмолор."))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Search Bar & Filter Header
                HStack(spacing: 12) {
                    // Search Input
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        TextField(tr("Поиск по вопросам, терминам или проблемам...", "Search questions, terms or problems...", "Суроолор, терминдер же көйгөйлөр боюнча издөө..."), text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                        
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tr("Очистить поле", "Clear the field", "Талааны тазалоо"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                
                // Category Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.key) { cat in
                            Button(action: {
                                selectedCategoryKey = cat.key
                            }) {
                                Text(cat.title)
                                    .font(.system(size: 12, weight: selectedCategoryKey == cat.key ? .semibold : .medium))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedCategoryKey == cat.key ? Theme.accent : Color.primary.opacity(0.05))
                                    .foregroundColor(selectedCategoryKey == cat.key ? Theme.onAccent : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // FAQ Accordion List
                VStack(spacing: 10) {
                    let items = filteredFAQs
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "questionmark.folder")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text(tr("По запросу «\(searchQuery)» ничего не найдено", "Nothing found for “\(searchQuery)”", "«\(searchQuery)» сурамы боюнча эч нерсе табылган жок"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(items) { item in
                            FAQAccordionCard(
                                item: item,
                                isExpanded: expandedItemIds.contains(item.id),
                                onToggle: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        if expandedItemIds.contains(item.id) {
                                            expandedItemIds.remove(item.id)
                                        } else {
                                            expandedItemIds.insert(item.id)
                                        }
                                    }
                                },
                                onPerformAction: {
                                    guard let tab = item.actionTab else { return }
                                    if item.actionTitle == tr("Сбросить кэш DNS сейчас", "Flush the DNS cache now", "DNS кэшин азыр тазалоо") {
                                        manager.flushDNS()
                                    } else if tab == .diagnostics {
                                        manager.runDiagnostics()
                                    } else if tab == .vpn && item.actionTitle == tr("Настроить Split Tunneling", "Configure split tunnelling", "Split Tunneling жөндөө") {
                                        manager.vpnSubTab = 1
                                    }
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        manager.selectedTab = tab
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
    }
    
    private var filteredFAQs: [FAQItem] {
        var list = FAQItem.allFAQs
        if selectedCategoryKey != "all" {
            list = list.filter { $0.categoryKey == selectedCategoryKey }
        }
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            list = list.filter {
                $0.question.localizedCaseInsensitiveContains(searchQuery) ||
                $0.answer.localizedCaseInsensitiveContains(searchQuery) ||
                $0.category.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        return list
    }
}

// MARK: - FAQ Accordion Card Component
struct FAQAccordionCard: View {
    let item: FAQItem
    let isExpanded: Bool
    let onToggle: () -> Void
    let onPerformAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Row (Clickable across full width)
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(item.category)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 8)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isExpanded ? Theme.accent : .secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggle()
            }
            
            // Expanded Answer Body
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().opacity(0.2)
                    
                    Text(item.answer)
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .foregroundColor(.primary.opacity(0.85))
                        .padding(.top, 4)
                        .textSelection(.enabled)
                    
                    if let actionTitle = item.actionTitle {
                        Button(action: onPerformAction) {
                            HStack(spacing: 6) {
                                Text(actionTitle)
                                    .font(.system(size: 11, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.accent.opacity(0.15))
                            .foregroundColor(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .bentoCard(cornerRadius: 14, padding: 0, interactive: true)
    }
}
