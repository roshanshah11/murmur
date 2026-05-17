// Root SwiftUI Settings scene. Tab selection persists across launches.
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, recording, vocabulary, prompts, models, updates, about
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .general:    return "gear"
        case .recording:  return "mic.circle"
        case .vocabulary: return "text.book.closed"
        case .prompts:    return "wand.and.rays"
        case .models:     return "cube.box"
        case .updates:    return "arrow.down.circle"
        case .about:      return "info.circle"
        }
    }
}

struct SettingsRoot: View {
    @AppStorage("settings.selectedTab") private var selectedRaw: String = SettingsTab.general.rawValue

    var body: some View {
        TabView(selection: Binding(
            get: { SettingsTab(rawValue: selectedRaw) ?? .general },
            set: { selectedRaw = $0.rawValue }
        )) {
            GeneralTab()    .tabItem { Label("General",    systemImage: SettingsTab.general.systemImage) }    .tag(SettingsTab.general)
            RecordingTab()  .tabItem { Label("Recording",  systemImage: SettingsTab.recording.systemImage) }  .tag(SettingsTab.recording)
            VocabularyTab() .tabItem { Label("Vocabulary", systemImage: SettingsTab.vocabulary.systemImage) } .tag(SettingsTab.vocabulary)
            PromptsTab()    .tabItem { Label("Prompts",    systemImage: SettingsTab.prompts.systemImage) }    .tag(SettingsTab.prompts)
            ModelsTab()     .tabItem { Label("Models",     systemImage: SettingsTab.models.systemImage) }     .tag(SettingsTab.models)
            UpdatesTab()    .tabItem { Label("Updates",    systemImage: SettingsTab.updates.systemImage) }    .tag(SettingsTab.updates)
            AboutTab()      .tabItem { Label("About",      systemImage: SettingsTab.about.systemImage) }      .tag(SettingsTab.about)
        }
        .frame(width: 580, height: 420)
    }
}
