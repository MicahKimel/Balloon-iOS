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
    @AppStorage("highScore") private var highScore = 0
    @AppStorage("totalCoins") private var totalCoins = 0
    
    // Selected styles
    @AppStorage("selectedBalloonStyleID") private var selectedBalloonStyleID = 0
    @AppStorage("selectedArrowStyleID") private var selectedArrowStyleID = 0
    @AppStorage("selectedBackgroundStyleID") private var selectedBackgroundStyleID = 0
    
    // Extra cosmetic toggle
    @AppStorage("enableBalloonTrail") private var enableBalloonTrail = false
    
    @State private var gameID = UUID()
    @State private var isShowingCustomization = false

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
                // Game Over Menu
                VStack(spacing: 24) {
                    Text("GAME OVER")
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(.red)
                    
                    Text("Score: \(score)")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("High Score: \(highScore)")
                        .foregroundColor(.gray)
                    
                    // Coins summary
                    HStack(spacing: 12) {
                        Image(systemName: "circle.grid.2x2.fill")
                            .foregroundColor(.yellow)
                        Text("Coins: \(totalCoins)")
                            .foregroundColor(.yellow)
                            .font(.headline)
                    }
                    .padding(.top, 4)

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
                    }
                }
                .padding(.horizontal, 32)
                .transition(.opacity)
                .zIndex(1) // Ensures menu stays on top
                .sheet(isPresented: $isShowingCustomization) {
                    CustomizationView()
                }
            } else {
                // The Game
                SpriteView(scene: createScene())
                    .id(gameID)
                    .zIndex(0)
            }
        }
    }

    func createScene() -> GameScene {
        let scene = GameScene(size: CGSize(width: 400, height: 800))
        scene.scaleMode = .aspectFill
        
        let balloonStyle = BalloonStyles.style(for: selectedBalloonStyleID)
        let arrowStyle = ArrowStyles.style(for: selectedArrowStyleID)
        let backgroundStyle = BackgroundStyles.style(for: selectedBackgroundStyleID)
        
        scene.applyAppearance(
            balloonColor: balloonStyle.color,
            arrowShaftColor: arrowStyle.shaftColor,
            arrowHeadColor: arrowStyle.headColor,
            arrowFeatherColor: arrowStyle.featherColor,
            backgroundColor: backgroundStyle.color,
            enableTrail: enableBalloonTrail
        )
        
        scene.onGameOver = { finalScore in
            // Logic to update scores and toggle the view
            self.score = finalScore
            if finalScore > highScore {
                highScore = finalScore
            }
            
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
        gameID = UUID() // Generate new ID to recreate the scene
    }
}


#Preview {
    ContentView()
}
