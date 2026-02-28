import SwiftUI

struct CustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("totalCoins") private var totalCoins = 0
    
    @AppStorage("selectedBalloonStyleID") private var selectedBalloonStyleID = 0
    @AppStorage("selectedArrowStyleID") private var selectedArrowStyleID = 0
    @AppStorage("selectedBackgroundStyleID") private var selectedBackgroundStyleID = 0
    
    // Unlock storage (comma separated lists for simplicity)
    @AppStorage("unlockedBalloonStyleIDs") private var unlockedBalloonIDsRaw: String = "0"
    @AppStorage("unlockedArrowStyleIDs") private var unlockedArrowIDsRaw: String = "0"
    @AppStorage("unlockedBackgroundStyleIDs") private var unlockedBackgroundIDsRaw: String = "0"
    
    @AppStorage("enableBalloonTrail") private var enableBalloonTrail = false
    
    // MARK: - Computed Properties (Read-Only)
    private var unlockedBalloonIDs: Set<Int> {
        Self.decodeIDSet(from: unlockedBalloonIDsRaw, defaultIDs: [0])
    }
    
    private var unlockedArrowIDs: Set<Int> {
        Self.decodeIDSet(from: unlockedArrowIDsRaw, defaultIDs: [0])
    }
    
    private var unlockedBackgroundIDs: Set<Int> {
        Self.decodeIDSet(from: unlockedBackgroundIDsRaw, defaultIDs: [0])
    }
    
    // MARK: - ID Helpers
    private static func decodeIDSet(from raw: String, defaultIDs: [Int]) -> Set<Int> {
        let parts = raw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let base = parts.isEmpty ? defaultIDs : parts
        return Set(base)
    }
    
    private static func encodeIDSet(_ set: Set<Int>) -> String {
        set.sorted().map(String.init).joined(separator: ",")
    }
    
    // MARK: - Main View
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Label("Coins", systemImage: "circle.grid.2x2.fill")
                            .foregroundColor(.yellow)
                        Spacer()
                        Text("\(totalCoins)")
                            .font(.headline)
                            .foregroundColor(.yellow)
                    }
                }
                
                balloonSection
                arrowSection
                backgroundSection
                
                Section("Extras") {
                    Toggle(isOn: $enableBalloonTrail) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Balloon Ghost Trail")
                            Text("Leaves a fading trail behind the balloon as it moves.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Customize")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var balloonSection: some View {
        Section("Balloon Color") {
            ForEach(BalloonStyles.all) { style in
                let isUnlocked = unlockedBalloonIDs.contains(style.id)
                let isSelected = selectedBalloonStyleID == style.id
                
                HStack {
                    Circle()
                        .fill(Color(uiColor: style.color))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.name)
                        Text(isUnlocked ? "Owned" : "Cost: \(style.cost) coins")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isUnlocked {
                        Button("Equip") {
                            selectedBalloonStyleID = style.id
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    } else {
                        Button("Buy") {
                            purchaseBalloon(style)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(totalCoins < style.cost)
                    }
                }
            }
        }
    }
    
    private var arrowSection: some View {
        Section("Arrow Style") {
            ForEach(ArrowStyles.all) { style in
                let isUnlocked = unlockedArrowIDs.contains(style.id)
                let isSelected = selectedArrowStyleID == style.id
                
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 80, height: 22)
                        
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(uiColor: style.shaftColor))
                                .frame(width: 40, height: 4)
                            TriangleShape()
                                .fill(Color(uiColor: style.headColor))
                                .frame(width: 16, height: 12)
                            Rectangle()
                                .fill(Color(uiColor: style.featherColor))
                                .frame(width: 10, height: 6)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.name)
                        Text(isUnlocked ? "Owned" : "Cost: \(style.cost) coins")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isUnlocked {
                        Button("Equip") {
                            selectedArrowStyleID = style.id
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    } else {
                        Button("Buy") {
                            purchaseArrow(style)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(totalCoins < style.cost)
                    }
                }
            }
        }
    }
    
    private var backgroundSection: some View {
        Section("Background Theme") {
            ForEach(BackgroundStyles.all) { style in
                let isUnlocked = unlockedBackgroundIDs.contains(style.id)
                let isSelected = selectedBackgroundStyleID == style.id
                
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(uiColor: style.color))
                        .frame(width: 60, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(radius: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.name)
                        Text(isUnlocked ? "Owned" : "Cost: \(style.cost) coins")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isUnlocked {
                        Button("Equip") {
                            selectedBackgroundStyleID = style.id
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    } else {
                        Button("Buy") {
                            purchaseBackground(style)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(totalCoins < style.cost)
                    }
                }
            }
        }
    }
    
    // MARK: - Purchases (Updated to avoid self-mutating error)
    
    private func purchaseBalloon(_ style: BalloonStyleDefinition) {
        guard totalCoins >= style.cost else { return }
        totalCoins -= style.cost
        
        var currentSet = unlockedBalloonIDs
        currentSet.insert(style.id)
        
        // Update the @AppStorage string directly
        unlockedBalloonIDsRaw = Self.encodeIDSet(currentSet)
        selectedBalloonStyleID = style.id
    }
    
    private func purchaseArrow(_ style: ArrowStyleDefinition) {
        guard totalCoins >= style.cost else { return }
        totalCoins -= style.cost
        
        var currentSet = unlockedArrowIDs
        currentSet.insert(style.id)
        
        // Update the @AppStorage string directly
        unlockedArrowIDsRaw = Self.encodeIDSet(currentSet)
        selectedArrowStyleID = style.id
    }
    
    private func purchaseBackground(_ style: BackgroundStyleDefinition) {
        guard totalCoins >= style.cost else { return }
        totalCoins -= style.cost
        
        var currentSet = unlockedBackgroundIDs
        currentSet.insert(style.id)
        
        // Update the @AppStorage string directly
        unlockedBackgroundIDsRaw = Self.encodeIDSet(currentSet)
        selectedBackgroundStyleID = style.id
    }
}

// MARK: - Helper Components
struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}