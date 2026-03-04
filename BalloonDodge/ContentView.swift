//
//  ContentView.swift
//  BalloonDodge
//
//  Created by Micah Kimel on 2/13/26.
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var isGameOver = false
    @State private var score = 0
    @AppStorage("individualHighScore") private var individualHighScore = 0
    @AppStorage("familyHighScore") private var familyHighScore = 0
    @AppStorage("totalCoins") private var totalCoins = 0
    @AppStorage("hasSeenIntroStory") private var hasSeenIntroStory = false
    @AppStorage("familyModeUnlocked") private var familyModeUnlocked = false
    @AppStorage("preferredMode") private var preferredMode = 0 // 0 = individual, 1 = family
    @AppStorage("lastLoginDate") private var lastLoginDate = ""
    
    // Selected styles
    @AppStorage("selectedBalloonStyleID") private var selectedBalloonStyleID = 0
    @AppStorage("selectedArrowStyleID") private var selectedArrowStyleID = 0
    @AppStorage("selectedBackgroundStyleID") private var selectedBackgroundStyleID = 0
    
    // Extra cosmetic toggle
    @AppStorage("enableBalloonTrail") private var enableBalloonTrail = false
    
    @State private var gameID = UUID()
    @State private var isShowingCustomization = false
    @State private var isShowingIntroStory = false
    @State private var isShowingAchievements = false
    @State private var isShowingStoryLog = false
    @State private var isShowingDailyBonus = false
    @State private var dailyBonusAmount = 0
    @State private var isNewHighScore = false

    private var currentBackgroundColor: Color {
        let bg = BackgroundStyles.style(for: selectedBackgroundStyleID)
        return Color(uiColor: bg.color)
    }

    var body: some View {
        ZStack {
            // Use selected background color so the whole app reflects the style
            currentBackgroundColor
                .ignoresSafeArea()
            
            if isGameOver {
                ZStack {
                    if isNewHighScore {
                        FireworksView()
                            .ignoresSafeArea()
                            .zIndex(0)
                    }
                    
                    // Game Over Menu
                    VStack(spacing: 24) {
                        Text("GAME OVER")
                            .font(.system(size: 48, weight: .black))
                            .foregroundColor(.red)
                        
                        Text("Score: \(score)")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 4) {
                            Text("Individual Best: \(individualHighScore)")
                                .foregroundColor(.gray)
                            Text("Family Best: \(familyHighScore)")
                                .foregroundColor(.gray)
                        }
                        
                        // Coins summary
                        HStack(spacing: 12) {
                            Image(systemName: "circle.grid.2x2.fill")
                                .foregroundColor(.yellow)
                            Text("Coins: \(totalCoins)")
                                .foregroundColor(.yellow)
                                .font(.headline)
                        }
                        .padding(.top, 4)

                        // Mode selection (after family is found)
                        if familyModeUnlocked {
                            VStack(spacing: 8) {
                                Text(preferredMode == 0 ? "Individual Run" : "Family Run")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    Button("Individual Mode") {
                                        preferredMode = 0
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(preferredMode == 0 ? .blue : .gray)
                                    
                                    Button("Family Mode") {
                                        preferredMode = 1
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(preferredMode == 1 ? .green : .gray)
                                }
                            }
                        }

                        // Primary actions
                        VStack(spacing: 12) {
                            Button("PLAY AGAIN") {
                                restartGame()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            
                            Button {
                                isShowingCustomization = true
                            } label: {
                                Label("Customize Look", systemImage: "paintpalette.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            
                            HStack(spacing: 12) {
                                Button {
                                    isShowingAchievements = true
                                } label: {
                                    Label("Badges", systemImage: "star.circle.fill")
                                }
                                .buttonStyle(.bordered)
                                
                                Button {
                                    isShowingStoryLog = true
                                } label: {
                                    Label("Story Log", systemImage: "book.closed.fill")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .transition(.opacity)
                    .zIndex(1) // Ensures menu stays on top
                    
                    // High score banner over everything when fireworks are playing
                    if isNewHighScore {
                        VStack {
                            Text("NEW HIGH SCORE!")
                                .font(.system(size: 34, weight: .black))
                                .foregroundColor(.green)
                                .shadow(radius: 8)
                                .padding(.top, 40)
                            
                            Text("\(score)")
                                .font(.system(size: 44, weight: .heavy))
                                .foregroundColor(.green)
                                .shadow(radius: 8)
                            
                            Spacer()
                        }
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(2)
                    }
                }
            } else {
                // The Game
                SpriteView(scene: createScene())
                    .id(gameID)
                    .zIndex(0)
            }
        }
        .onAppear {
            if !hasSeenIntroStory {
                isShowingIntroStory = true
            }
            
            // Daily login bonus: once per calendar day
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())
            if lastLoginDate != today {
                lastLoginDate = today
                let bonus = 25
                totalCoins += bonus
                dailyBonusAmount = bonus
                isShowingDailyBonus = true
            }
        }
        .fullScreenCover(isPresented: $isShowingIntroStory) {
            StoryIntroView {
                hasSeenIntroStory = true
                isShowingIntroStory = false
            }
        }
        .sheet(isPresented: $isShowingCustomization) {
            CustomizationView()
        }
        .sheet(isPresented: $isShowingAchievements) {
            AchievementsView()
        }
        .sheet(isPresented: $isShowingStoryLog) {
            StoryLogView()
        }
        .sheet(isPresented: $isShowingDailyBonus) {
            DailyBonusView(bonusAmount: dailyBonusAmount) {
                isShowingDailyBonus = false
            }
        }
    }

    func createScene() -> GameScene {
        let scene = GameScene(size: CGSize(width: 400, height: 800))
        scene.scaleMode = .aspectFill
        
        let playingFamily = familyModeUnlocked && preferredMode == 1
        
        let balloonStyle = BalloonStyles.style(for: selectedBalloonStyleID)
        let arrowStyle = ArrowStyles.style(for: selectedArrowStyleID)
        let backgroundStyle = BackgroundStyles.style(for: selectedBackgroundStyleID)
        
        scene.applyAppearance(
            balloonColor: balloonStyle.color,
            arrowShaftColor: arrowStyle.shaftColor,
            arrowHeadColor: arrowStyle.headColor,
            arrowFeatherColor: arrowStyle.featherColor,
            backgroundColor: backgroundStyle.color,
            enableTrail: enableBalloonTrail,
            familyMode: playingFamily
        )
        
        scene.onGameOver = { finalScore in
            // Logic to update scores and toggle the view
            self.score = finalScore
            var newHigh = false
            if playingFamily {
                if finalScore > familyHighScore {
                    familyHighScore = finalScore
                    newHigh = true
                }
            } else {
                if finalScore > individualHighScore {
                    individualHighScore = finalScore
                    newHigh = true
                }
            }
            isNewHighScore = newHigh
            
            // Add to persistent coins total
            totalCoins += finalScore
            
            // Force the UI update on the main thread
            withAnimation(.easeInOut) {
                self.isGameOver = true
            }
        }
        return scene
    }

    func restartGame() {
        // Resetting order matters
        score = 0
        isGameOver = false
        isNewHighScore = false
        gameID = UUID() // Generate new ID to recreate the scene
    }
}


#Preview {
    ContentView()
}
