import SwiftUI
import AppKit

/// Полоса «Доступна новая версия» под панелью инструментов.
/// Видна только когда `UpdateChecker` нашёл релиз новее этой сборки.
struct UpdateBanner: View {
    @ObservedObject private var checker = UpdateChecker.shared
    @ObservedObject private var updater = Updater.shared
    @ObservedObject private var l10n = LocalizationManager.shared

    var body: some View {
        if let release = checker.available {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(Theme.accent)
                        .font(.system(size: 14))
                    Text(statusText(release))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                    Spacer(minLength: 8)

                    if updater.isBusy {
                        ProgressView().controlSize(.small)
                        Button(tr("Отмена", "Cancel", "Жокко чыгаруу")) { updater.cancel() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Button(tr("Что нового", "What’s new", "Эмне жаңы")) {
                            NSWorkspace.shared.open(release.url)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                        Button(tr("Пропустить", "Skip", "Өткөрүп жиберүү")) { checker.skip(release) }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        if release.downloadURL != nil && Updater.canReplaceItself {
                            Button(tr("Обновить и перезапустить", "Update and Restart", "Жаңыртуу жана кайра ачуу")) {
                                updater.install(release)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(Theme.accent)
                            .foregroundColor(Theme.onAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        } else {
                            Button(tr("Скачать", "Download", "Жүктөп алуу")) {
                                NSWorkspace.shared.open(release.downloadURL ?? release.url)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(Theme.accent)
                            .foregroundColor(Theme.onAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.accent.opacity(0.08))
                Divider().opacity(0.2)
            }
        }
    }

    private func statusText(_ release: UpdateChecker.Release) -> String {
        switch updater.phase {
        case .downloading:
            return tr("Скачиваю версию \(release.version)…", "Downloading version \(release.version)…", "\(release.version) версиясы жүктөлүүдө…")
        case .verifying:
            return tr("Проверяю подпись…", "Verifying…", "Кол текшерилүүдө…")
        case .installing:
            return tr("Устанавливаю и перезапускаю…", "Installing and restarting…", "Орнотулуп, кайра ачылууда…")
        case .failed(let message):
            return tr("Не удалось обновить: \(message)", "Update failed: \(message)", "Жаңыртуу ишке ашкан жок: \(message)")
        case .idle:
            if !Updater.canReplaceItself {
                return tr("Доступна версия \(release.version). Чтобы обновлять в один клик, перенесите приложение в «Программы».",
                          "Version \(release.version) is available. Move the app to Applications to update in one click.",
                          "\(release.version) версиясы жеткиликтүү. Бир баскыч менен жаңыртуу үчүн программаны «Программалар» папкасына көчүрүңүз.")
            }
            return tr("Доступна версия \(release.version) (у вас \(UpdateChecker.currentVersion))",
                      "Version \(release.version) is available (you have \(UpdateChecker.currentVersion))",
                      "\(release.version) версиясы жеткиликтүү (сизде \(UpdateChecker.currentVersion))")
        }
    }
}

/// Строка «Обновления» в «О программе»: автопроверка и «Проверить сейчас».
struct UpdateSettingsRow: View {
    @ObservedObject private var checker = UpdateChecker.shared
    @ObservedObject private var l10n = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(get: { checker.isEnabled }, set: { checker.setEnabled($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Проверять обновления раз в день", "Check for updates daily", "Жаңыртууларды күнүнө бир жолу текшерүү"))
                        .font(.system(size: 12, weight: .medium))
                    Text(checker.lastResult ?? tr("Источник: релизы на GitHub", "Source: GitHub releases", "Булак: GitHub'дагы релиздер"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            Spacer()
            Button(action: { Task { await checker.check() } }) {
                if checker.isChecking {
                    ProgressView().controlSize(.small)
                } else {
                    Text(tr("Проверить сейчас", "Check now", "Азыр текшерүү"))
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .disabled(checker.isChecking)
        }
        .padding(12)
        .background(Theme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
