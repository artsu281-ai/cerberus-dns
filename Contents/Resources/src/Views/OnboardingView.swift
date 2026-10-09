import SwiftUI

/// Мастер первого запуска.
///
/// Раньше человек при первом открытии попадал сразу на панель с девятью
/// вкладками и должен был сам догадаться, что нажать.
///
/// Ключевой здесь третий шаг. Он не рисует галочку по факту нажатия кнопки, а
/// запускает настоящую проверку двенадцати рекламных доменов и показывает её
/// результат — включая случай, когда защита включена, но системный резолвер
/// перехвачен посторонним софтом и фильтрация не действует. Именно на этом
/// приложение молча вводило в заблуждение.
struct OnboardingView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject private var l10n = LocalizationManager.shared

    enum Step: Int, CaseIterable { case welcome, profile, verify }

    @State private var step: Step = .welcome
    @State private var didStartCheck = false

    private var isRu: Bool { l10n.currentLanguage == .ru }

    var body: some View {
        ZStack {
            Theme.windowBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.15)

                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .profile: profileStep
                    case .verify:  verifyStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().opacity(0.15)
                footer
            }
        }
        .transition(.opacity)
    }

    // MARK: - Шапка с индикатором шагов

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = AppPaths.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
            }

            Text(L("app.title"))
                .font(.system(size: 13, weight: .bold))

            Spacer()

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Theme.accent : Color.primary.opacity(0.12))
                        .frame(width: s == step ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: step)
                }
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 52)
        .chromeSurface()
    }

    // MARK: - Шаг 1. Что это

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                if let icon = AppPaths.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 92, height: 92)
                        .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
                }

                VStack(spacing: 8) {
                    Text(tr("Реклама не загрузится", "Ads never load", "Жарнама жүктөлбөйт"))
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text(tr("Cerberus отсеивает рекламу и трекеры на уровне доменных имён — до того, как страница начнёт их скачивать. Работает во всех программах сразу, не только в браузере, и не расходует батарею.", "Cerberus drops ads and trackers at the domain level, before a page starts downloading them. It works across every app at once, not just the browser, and costs no battery.", "Cerberus жарнаманы жана трекерлерди домен аттарынын деңгээлинде чыпкалайт — барак аларды жүктөй электе. Браузерде гана эмес, бардык программаларда бир убакта иштейт жана батареяны коротпойт."))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 460)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Шаг 2. Включение

    private var profileStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(alreadyProtected
                         ? (tr("Фильтр уже включён", "The filter is already on", "Чыпка буга чейин күйгүзүлгөн"))
                         : (tr("Включаем фильтр", "Turning on the filter", "Чыпканы күйгүзөбүз")))
                        .font(.system(size: 22, weight: .bold))

                    // При повторном запуске мастера профиль не переключается.
                    // Иначе выбранный человеком Quad9 или Mullvad молча
                    // заменился бы на AdGuard — мастер испортил бы настройку,
                    // которую пришёл проверить.
                    Text(alreadyProtected
                         ? (tr("Сейчас активен профиль «\(manager.currentProfile.title)». Менять его мастер не станет — сразу перейдём к проверке.", "The active profile is “\(manager.currentProfile.title)”. The wizard will not change it — we go straight to the check.", "Азыр «\(manager.currentProfile.title)» профили активдүү. Мастер аны өзгөртпөйт — дароо текшерүүгө өтөбүз."))
                         : (tr("Запросы пойдут через AdGuard DNS — публичный резолвер, который отбрасывает рекламные и следящие домены. Это можно изменить позже в разделе «Профили DNS».", "Queries will go through AdGuard DNS, a public resolver that drops ad and tracking domains. You can change this later under DNS Profiles.", "Сурамдар AdGuard DNS аркылуу өтөт — бул жарнамалык жана аңдуучу домендерди четке каккан ачык резолвер. Муну кийинчерээк «DNS профилдери» бөлүмүнөн өзгөртсө болот.")))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 480)
                }

                // Предупреждение о пароле: человек должен знать, что запрос
                // системный и ожидаемый, а не подозрительный.
                if !alreadyProtected {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: manager.isHelperInstalled ? "touchid" : "lock.shield")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .frame(width: 20)

                    Text(manager.isHelperInstalled
                         ? (tr("Пароль не потребуется — привилегированный помощник уже установлен.", "No password needed — the privileged helper is already installed.", "Сырсөз талап кылынбайт — артыкчылыктуу жардамчы мурунтан орнотулган."))
                         : (tr("macOS попросит пароль администратора: приложение меняет системные настройки DNS. Это единственное, что оно делает с правами root.", "macOS will ask for your administrator password: the app changes system DNS settings. That is the only thing it does as root.", "macOS администратордун сырсөзүн сурайт: колдонмо системалык DNS жөндөөлөрүн өзгөртөт. Ал root укуктары менен ушуну гана жасайт.")))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: 480, alignment: .leading)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    /// Защита настроена ещё до мастера — значит, это повторный запуск.
    private var alreadyProtected: Bool { manager.isProtected }

    // MARK: - Шаг 3. Проверка

    private var verifyStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(verdictColor.opacity(0.14))
                        .frame(width: 74, height: 74)

                    if manager.isDiagnosing {
                        ProgressView().controlSize(.large)
                    } else {
                        Image(systemName: verdictIcon)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(verdictColor)
                    }
                }

                VStack(spacing: 8) {
                    Text(verdictTitle)
                        .font(.system(size: 21, weight: .bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(verdictBody)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 470)
                }

                if !manager.isDiagnosing && !checkedItems.isEmpty {
                    HStack(spacing: 7) {
                        ForEach(checkedItems.prefix(12)) { item in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(item.blocked ? Theme.statusGreen : Theme.statusRed.opacity(0.75))
                                .frame(width: 20, height: 5)
                        }
                    }
                    .help(tr("Каждая полоска — один проверенный домен", "Each bar is one checked domain", "Ар бир тилке — бир текшерилген домен"))
                }

                // Подсказка про строку меню: без неё человек закрывает окно и
                // решает, что приложение исчезло.
                if !manager.isDiagnosing {
                    HStack(spacing: 8) {
                        Image(systemName: "menubar.arrow.up.rectangle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text(tr("Cerberus остаётся в строке меню — оттуда его можно выключить или поставить на паузу.", "Cerberus stays in the menu bar — you can pause or disable it from there.", "Cerberus меню сабында калат — ал жерден аны өчүрүп же тыныгууга коюуга болот."))
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: 470)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear {
            guard !didStartCheck else { return }
            didStartCheck = true
            manager.refreshStatus()
            manager.runDiagnostics()
        }
        .onDisappear { didStartCheck = false }
    }

    // MARK: - Подвал

    private var footer: some View {
        HStack(spacing: 12) {
            if step == .welcome {
                Button(action: { manager.completeOnboarding() }) {
                    Text(tr("Пропустить", "Skip", "Өткөрүп жиберүү"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if step == .verify, manager.dnsOverridden, !manager.isDiagnosing {
                Button(action: {
                    manager.selectedTab = .diagnostics
                    manager.completeOnboarding()
                }) {
                    Text(tr("Открыть диагностику", "Open diagnostics", "Диагностиканы ачуу"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if step == .verify, !manager.isHelperInstalled, !manager.isDiagnosing {
                Button(action: { manager.installPrivilegedHelper() }) {
                    Text(tr("Больше не спрашивать пароль", "Stop asking for the password", "Сырсөздү мындан ары сурабоо"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: primaryAction) {
                HStack(spacing: 6) {
                    Text(primaryTitle)
                        .font(.system(size: 12.5, weight: .semibold))
                    if step != .verify {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 30)
                .background(Theme.accent)
                .foregroundColor(Theme.onAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(manager.isBusy || (step == .verify && manager.isDiagnosing))
            .opacity(manager.isBusy || (step == .verify && manager.isDiagnosing) ? 0.5 : 1)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 22)
        .frame(height: 58)
        .chromeSurface()
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: return tr("Начать", "Get started", "Баштоо")
        case .profile: return alreadyProtected
            ? (tr("Проверить", "Check now", "Текшерүү"))
            : (tr("Включить защиту", "Turn on protection", "Коргоону күйгүзүү"))
        case .verify:  return tr("Готово", "Done", "Даяр")
        }
    }

    private func primaryAction() {
        switch step {
        case .welcome:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { step = .profile }

        case .profile:
            guard !alreadyProtected else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { step = .verify }
                return
            }
            let profile = DNSProfile.allProfiles.first(where: { $0.id == "adguard" })
                ?? DNSProfile.allProfiles[0]
            // Переход к проверке — по факту завершения, а не по таймеру:
            // запрос пароля может занять сколько угодно времени.
            manager.applyProfile(profile) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { step = .verify }
            }

        case .verify:
            manager.completeOnboarding()
        }
    }

    // MARK: - Результат проверки

    private var checkedItems: [DiagnosticItem] {
        manager.diagnosticResults.filter { !$0.isControl && !$0.didFail }
    }

    private var blockedCount: Int {
        checkedItems.filter { $0.blocked }.count
    }

    private var percent: Int {
        guard !checkedItems.isEmpty else { return 0 }
        return Int(round(Double(blockedCount) / Double(checkedItems.count) * 100))
    }

    private enum Verdict { case running, overridden, good, partial, failed }

    private var verdict: Verdict {
        if manager.isDiagnosing || checkedItems.isEmpty { return .running }
        if manager.dnsOverridden { return .overridden }
        if percent >= 70 { return .good }
        if percent > 0 { return .partial }
        return .failed
    }

    private var verdictColor: Color {
        switch verdict {
        case .running:                 return Theme.accent
        case .good:                    return Theme.statusGreen
        case .overridden, .partial:    return Theme.statusOrange
        case .failed:                  return Theme.statusRed
        }
    }

    private var verdictIcon: String {
        switch verdict {
        case .running:    return "hourglass"
        case .good:       return "checkmark.shield.fill"
        case .overridden: return "exclamationmark.triangle.fill"
        case .partial:    return "shield.lefthalf.filled"
        case .failed:     return "xmark.shield.fill"
        }
    }

    private var verdictTitle: String {
        switch verdict {
        case .running:
            return tr("Проверяем...", "Checking...", "Текшерип жатабыз...")
        case .good:
            return tr("Работает", "It works", "Иштеп жатат")
        case .overridden:
            return tr("Включено, но не действует", "Enabled, but not in effect", "Күйгүзүлгөн, бирок иштебей жатат")
        case .partial:
            return tr("Работает частично", "Partly working", "Жарым-жартылай иштеп жатат")
        case .failed:
            return tr("Реклама всё ещё проходит", "Ads still get through", "Жарнама дагы эле өтүп жатат")
        }
    }

    private var verdictBody: String {
        switch verdict {
        case .running:
            return tr("Запрашиваем двенадцать настоящих рекламных и следящих доменов и смотрим, что ответит система.", "Resolving twelve real ad and tracking domains to see what the system answers.", "Он эки чыныгы жарнамалык жана аңдуучу доменди сурап, система эмне жооп берерин карап жатабыз.")

        case .good:
            return tr("Проверили \(checkedItems.count) рекламных доменов — заблокировано \(blockedCount). Ничего настраивать больше не нужно.", "Checked \(checkedItems.count) ad domains — \(blockedCount) blocked. Nothing else to set up.", "\(checkedItems.count) жарнамалык домен текшерилди — \(blockedCount) бөгөттөлдү. Башка эч нерсе жөндөөнүн кереги жок.")

        case .overridden:
            let source = manager.overrideSource.isEmpty
                ? (tr("сторонний резолвер", "another resolver", "башка резолвер"))
                : manager.overrideSource
            let resolver = manager.effectiveResolver.isEmpty ? "—" : manager.effectiveResolver
            return tr("Фильтр включён, но запросы уходят на \(resolver) — это \(source), и он выше по приоритету. Пока этот источник активен, реклама блокироваться не будет. Отключите его или настройте фильтрацию в нём.", "The filter is on, but queries go to \(resolver) — that is \(source), and it takes priority. While it is active nothing will be blocked. Disable it or configure filtering there.", "Чыпка күйүк, бирок сурамдар \(resolver) дарегине кетип жатат — бул \(source), анын артыкчылыгы жогору. Бул булак активдүү турганда жарнама бөгөттөлбөйт. Аны өчүрүңүз же андагы чыпкалоону жөндөңүз.")

        case .partial:
            return tr("Из \(checkedItems.count) доменов заблокировано \(blockedCount). Остальные могли быть закэшированы системой — попробуйте сбросить кэш DNS в разделе «Инструменты».", "\(blockedCount) of \(checkedItems.count) domains were blocked. The rest may be cached by the system — try flushing the DNS cache under Tools.", "\(checkedItems.count) домендин \(blockedCount) бөгөттөлдү. Калгандары система тарабынан кэштелип калышы мүмкүн — «Куралдар» бөлүмүндө DNS кэшин тазалап көрүңүз.")

        case .failed:
            return tr("Ни один из \(checkedItems.count) проверенных доменов не заблокирован. Скорее всего, DNS перехватывает другая программа либо браузер использует собственный шифрованный резолвер.", "None of the \(checkedItems.count) checked domains were blocked. Most likely another program is intercepting DNS, or the browser uses its own encrypted resolver.", "Текшерилген \(checkedItems.count) домендин бири да бөгөттөлгөн жок. Балким, DNS сурамдарын башка программа кармап жатат же браузер өзүнүн шифрленген резолверин колдонот.")
        }
    }
}
