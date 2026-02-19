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
    @AppStorage("highScore") var highScore = 0
    @State private var gameID = UUID()

    var body: some View {
        ZStack {
            // Background color is always present to prevent white flashes
            Color.black.ignoresSafeArea()
            
            if isGameOver {
                // Game Over Menu
                VStack(spacing: 25) {
                    Text("GAME OVER")
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(.red)
                    
                    Text("Score: \(score)")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("High Score: \(highScore)")
                        .foregroundColor(.gray)

                    Button("PLAY AGAIN") {
                        restartGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .transition(.opacity)
                .zIndex(1) // Ensures menu stays on top
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
        scene.onGameOver = { finalScore in
            // Logic to update scores and toggle the view
            self.score = finalScore
            if finalScore > highScore {
                highScore = finalScore
            }
            
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
