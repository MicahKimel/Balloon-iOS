import SpriteKit

class FireworksScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        
        let spawn = SKAction.run { [weak self] in
            self?.launchFirework()
        }
        let wait = SKAction.wait(forDuration: 0.25)
        run(SKAction.repeatForever(SKAction.sequence([spawn, wait])))
    }
    
    private func launchFirework() {
        let startX = CGFloat.random(in: 0.15...0.85) * size.width
        let startY: CGFloat = -40
        let peakY = CGFloat.random(in: size.height * 0.4...size.height * 0.8)
        
        let shell = SKShapeNode(circleOfRadius: 4)
        shell.fillColor = .white
        shell.strokeColor = .clear
        shell.position = CGPoint(x: startX, y: startY)
        shell.zPosition = 1
        addChild(shell)
        
        let rise = SKAction.move(to: CGPoint(x: startX, y: peakY), duration: 0.6)
        rise.timingMode = .easeOut
        
        let explode = SKAction.run { [weak self, weak shell] in
            guard let self = self, let shell = shell else { return }
            self.createExplosion(at: shell.position)
            shell.removeFromParent()
        }
        
        shell.run(SKAction.sequence([rise, explode]))
    }
    
    private func createExplosion(at position: CGPoint) {
        let colors: [SKColor] = [
            .systemRed, .systemBlue, .systemGreen,
            .systemYellow, .systemPurple, .systemPink, .white
        ]
        let baseColor = colors.randomElement() ?? .white
        
        let count = 40
        for i in 0..<count {
            let angle = (CGFloat(i) / CGFloat(count)) * (.pi * 2)
            let speed = CGFloat.random(in: 120...220)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            
            let spark = SKShapeNode(circleOfRadius: 2.5)
            spark.fillColor = baseColor
            spark.strokeColor = .clear
            spark.position = position
            spark.zPosition = 1
            addChild(spark)
            
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.8)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.8)
            let scale = SKAction.scale(to: 0.5, duration: 0.8)
            let group = SKAction.group([move, fade, scale])
            spark.run(SKAction.sequence([group, .removeFromParent()]))
        }
    }
}

