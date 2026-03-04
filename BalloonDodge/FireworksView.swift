import SwiftUI
import SpriteKit
import UIKit

struct FireworksView: View {
    private var scene: SKScene {
        let size = UIScreen.main.bounds.size
        let scene = FireworksScene(size: size)
        scene.scaleMode = .resizeFill
        return scene
    }
    
    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}

