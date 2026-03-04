import SwiftUI

struct StoryLogView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("storyLog") private var storyLogRaw: String = ""
    
    private var entries: [String] {
        storyLogRaw
            .split(separator: "\n")
            .map { String($0) }
            .reversed()
    }
    
    var body: some View {
        NavigationView {
            Group {
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Text("No Story Yet")
                            .font(.headline)
                        Text("Survive runs and hit story milestones to record your journey here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
                } else {
                    List {
                        ForEach(entries, id: \.self) { line in
                            Text(line)
                                .font(.footnote)
                                .foregroundColor(.primary)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Story Log")
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

