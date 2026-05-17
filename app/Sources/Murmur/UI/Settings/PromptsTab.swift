// Phase 3: Prompts tab — pick the active cleanup profile and watch four
// side-by-side previews update live as you type.
//
// Profiles live in PromptLibrary (Phase 2). This tab is purely a picker
// + preview surface; the actual transforms run in TextCleaner.
import Combine
import SwiftUI

// MARK: - View model

@MainActor
final class PromptsTabModel: ObservableObject {
    @Published var sampleInput: String
    @Published var activeProfile: PromptLibrary.Profile

    private let store: SettingsStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: SettingsStore? = nil,
         defaultSample: String = "um, like, i don't know if the api equals equals null") {
        let resolvedStore = store ?? SettingsStore.shared
        self.store = resolvedStore
        self.sampleInput = defaultSample
        self.activeProfile = resolvedStore.config.activeProfile

        // Keep the model in sync if another window (e.g. CLI flag, future
        // shortcut) changes the active profile underneath us.
        resolvedStore.$config
            .map(\.activeProfile)
            .removeDuplicates()
            .sink { [weak self] new in
                guard let self else { return }
                if new != self.activeProfile {
                    self.activeProfile = new
                }
            }
            .store(in: &cancellables)
    }

    /// Compute the cleaned output for an arbitrary profile, applying the
    /// user's current vocabulary on top so the four preview cards reflect
    /// what they'd actually see in the wild.
    func output(for profile: PromptLibrary.Profile) -> String {
        let cleaner = TextCleaner(
            vocabulary: store.config.vocabulary,
            profile: profile
        )
        return cleaner.clean(sampleInput)
    }

    /// User-driven profile pick. Pushes through `SettingsStore` so the
    /// change debounces to disk and any other tab listening to
    /// `.murmurConfigUpdated` refreshes.
    func selectProfile(_ profile: PromptLibrary.Profile) {
        activeProfile = profile
        store.update(\.activeProfile, to: profile)
    }
}

// MARK: - View

struct PromptsTab: View {
    @StateObject private var model = PromptsTabModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            picker
            sampleField
            previewGrid
            descriptions
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Prompts").font(.headline)
                Text("Choose how Murmur cleans your dictation before pasting.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            activePill
        }
    }

    private var activePill: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Active: \(model.activeProfile.displayName)")
                .font(.caption).bold()
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            Capsule().fill(Color.green.opacity(0.12))
        )
    }

    private var picker: some View {
        Picker("", selection: Binding(
            get: { model.activeProfile },
            set: { model.selectProfile($0) }
        )) {
            ForEach(PromptLibrary.Profile.allCases) { profile in
                Text(profile.displayName).tag(profile)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var sampleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sample input")
                .font(.caption).bold()
                .foregroundStyle(.secondary)
            TextField("type or paste a sample", text: $model.sampleInput)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var previewGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(PromptLibrary.Profile.allCases) { profile in
                PreviewCard(
                    profile: profile,
                    output: model.output(for: profile),
                    isActive: profile == model.activeProfile,
                    onSelect: { model.selectProfile(profile) }
                )
            }
        }
    }

    private var descriptions: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(PromptLibrary.Profile.allCases) { profile in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(profile.displayName).bold()
                        .frame(width: 56, alignment: .leading)
                    Text(Self.description(for: profile))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    static func description(for profile: PromptLibrary.Profile) -> String {
        switch profile {
        case .raw:    return "What Whisper heard. No edits at all."
        case .casual: return "Strip filler words. Capitalise. Tidy punctuation. The default."
        case .formal: return "All of Casual plus contractions expanded for emails and reports."
        case .code:   return "Translate spoken operators (equals equals, arrow) for programming dictation."
        }
    }
}

// MARK: - Card

private struct PreviewCard: View {
    let profile: PromptLibrary.Profile
    let output: String
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(profile.displayName)
                    .font(.subheadline).bold()
                if isActive {
                    Text("Active")
                        .font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.18))
                        .foregroundStyle(.tint)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            Text(output.isEmpty ? "(empty)" : output)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(output.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.18),
                        lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
