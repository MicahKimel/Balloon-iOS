import SwiftUI

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("achievement_score10") private var score10 = false
    @AppStorage("achievement_score50") private var score50 = false
    @AppStorage("achievement_score100") private var score100 = false
    @AppStorage("achievement_firstShield") private var firstShield = false
    @AppStorage("achievement_familyUnlocked") private var familyUnlocked = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    AchievementRow(
                        title: "First Drift",
                        detail: "Reach a score of 10.",
                        unlocked: score10
                    )
                    AchievementRow(
                        title: "Arrow Dancer",
                        detail: "Reach a score of 50.",
                        unlocked: score50
                    )
                    AchievementRow(
                        title: "Sky Legend",
                        detail: "Reach a score of 100.",
                        unlocked: score100
                    )
                }
                
                Section("Power & Protection") {
                    AchievementRow(
                        title: "First Shield",
                        detail: "Catch your first shimmering shield orb.",
                        unlocked: firstShield
                    )
                }
                
                Section("Story") {
                    AchievementRow(
                        title: "Found Family",
                        detail: "Unlock family mode and meet the other balloons.",
                        unlocked: familyUnlocked
                    )
                }
            }
            .navigationTitle("Badges")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AchievementRow: View {
    let title: String
    let detail: String
    let unlocked: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: unlocked ? "checkmark.seal.fill" : "lock.fill")
                .foregroundColor(unlocked ? .green : .gray)
        }
        .padding(.vertical, 4)
    }
}

