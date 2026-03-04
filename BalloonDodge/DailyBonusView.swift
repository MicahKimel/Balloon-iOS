import SwiftUI

struct DailyBonusView: View {
    let bonusAmount: Int
    var onClose: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                
                Text("Daily Sky Gift")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                
                Text("The sky remembers you today.\nYou found \(bonusAmount) bonus coins drifting on the wind.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Text("+\(bonusAmount) Coins")
                    .font(.title2.bold())
                    .foregroundColor(.yellow)
                
                Spacer()
                
                Button(action: onClose) {
                    Text("Float On")
                        .font(.headline.weight(.bold))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color.red, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                        .foregroundColor(.white)
                        .shadow(radius: 8)
                }
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.10),
                        Color(red: 0.20, green: 0.05, blue: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
        }
    }
}

