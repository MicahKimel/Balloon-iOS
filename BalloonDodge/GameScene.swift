//
//  GameScene.swift
//  BalloonDodge
//
//  Created by Micah Kimel on 2/19/26.
//


import SpriteKit
import UIKit


class GameScene: SKScene, SKPhysicsContactDelegate {
    var balloon: SKShapeNode!
    var score = 0
    var scoreLabel: SKLabelNode!
    var onGameOver: ((Int) -> Void)?
    
    // Appearance configuration (set from SwiftUI)
    private var balloonFillColor: UIColor = .systemRed
    private var arrowShaftColor: UIColor = UIColor(red: 0.82, green: 0.65, blue: 0.40, alpha: 1)
    private var arrowHeadColor: UIColor = UIColor(red: 0.75, green: 0.75, blue: 0.80, alpha: 1)
    private var arrowFeatherColor: UIColor = UIColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1)
    private var sceneBackgroundColor: UIColor = .black
    private var enableBalloonTrail: Bool = false
    
    // Trail state
    private var lastTrailSpawnTime: TimeInterval = 0

    // Rope simulation
    private var ropeSegments: [SKShapeNode] = []
    private var ropeDrawNode: SKShapeNode!      // single path redrawn every frame
    private let segmentCount  = 22              // number of chain links
    private let segmentLength: CGFloat = 6      // length of each link
    private let balloonRadius: CGFloat = 30
    
    private var isShielded = false
    private var shieldNode: SKShapeNode?

    // Unique IDs for physics categories
    struct PhysicsCategory {
        static let none:    UInt32 = 0
        static let balloon: UInt32 = 0b1
        static let arrow:   UInt32 = 0b10
        static let edge:    UInt32 = 0b100
        static let rope:    UInt32 = 0b1000
        static let powerUp: UInt32 = 0b10000
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero
        
        backgroundColor = sceneBackgroundColor

        let borderBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        borderBody.categoryBitMask = PhysicsCategory.edge
        self.physicsBody = borderBody

        setupBalloon()
        setupRope()
        setupScoreLabel()
        startArrowSpawning()
        startPowerUpSpawning()
    }

    // MARK: - Score

    func setupScoreLabel() {
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.text = "Score: 0"
        scoreLabel.fontSize = 28
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 60)
        scoreLabel.zPosition = 10
        addChild(scoreLabel)
    }

    func updateScore() {
        score += 1
        scoreLabel.text = "Score: \(score)"
    }

    // MARK: - Balloon

    func setupBalloon() {
        balloon = SKShapeNode(circleOfRadius: balloonRadius)
        balloon.fillColor = balloonFillColor
        balloon.strokeColor = .white
        balloon.lineWidth = 2
        balloon.position = CGPoint(x: frame.midX, y: frame.midY)

        let pBody = SKPhysicsBody(circleOfRadius: balloonRadius)
        pBody.isDynamic = true
        pBody.affectedByGravity = false
        pBody.categoryBitMask    = PhysicsCategory.balloon
        pBody.contactTestBitMask = PhysicsCategory.arrow
        pBody.collisionBitMask   = PhysicsCategory.edge
        balloon.physicsBody = pBody
        addChild(balloon)
    }

    // MARK: - Rope

    func setupRope() {
        // A lightweight draw node — no physics, just redrawn every frame
        ropeDrawNode = SKShapeNode()
        ropeDrawNode.strokeColor = .white
        ropeDrawNode.lineWidth = 1.5
        ropeDrawNode.zPosition = -1
        addChild(ropeDrawNode)

        // Build a chain of tiny physics segments pinned together
        var prevNode: SKNode = balloon
        let attachPointY = -balloonRadius          // bottom of balloon in balloon-local space

        for i in 0..<segmentCount {
            let seg = SKShapeNode(circleOfRadius: 1) // invisible; just a physics anchor
            seg.fillColor = .clear
            seg.strokeColor = .clear

            // World position: hanging straight down from balloon bottom initially
            let worldY = balloon.position.y + attachPointY - CGFloat(i) * segmentLength
            seg.position = CGPoint(x: balloon.position.x, y: worldY)

            let body = SKPhysicsBody(circleOfRadius: 1)
            body.isDynamic = true
            body.affectedByGravity = true
            body.mass = 0.001
            body.linearDamping = 0.8       // high damping = sluggish, rope-like feel
            body.angularDamping = 0.8
            body.categoryBitMask    = PhysicsCategory.rope
            body.contactTestBitMask = PhysicsCategory.none
            body.collisionBitMask   = PhysicsCategory.none  // rope passes through everything
            seg.physicsBody = body
            addChild(seg)
            ropeSegments.append(seg)

            // Pin this segment to the previous one (or to the balloon)
            let anchorInWorld: CGPoint
            if i == 0 {
                // Attach first segment to the bottom of the balloon
                anchorInWorld = CGPoint(x: balloon.position.x,
                                        y: balloon.position.y + attachPointY)
            } else {
                anchorInWorld = ropeSegments[i - 1].position
            }

            let pin = SKPhysicsJointPin.joint(withBodyA: prevNode.physicsBody!,
                                              bodyB: seg.physicsBody!,
                                              anchor: anchorInWorld)
            pin.shouldEnableLimits = true
            pin.upperAngleLimit  =  CGFloat.pi / 3   // limit swing so it stays rope-like
            pin.lowerAngleLimit  = -CGFloat.pi / 3
            physicsWorld.add(pin)

            prevNode = seg
        }
    }

    /// Redraws the rope as a smooth curve through all segment positions each frame.
    private func updateRopeDrawing() {
        guard !ropeSegments.isEmpty else { return }

        let path = CGMutablePath()

        // Start at the balloon's bottom
        let start = CGPoint(x: balloon.position.x,
                            y: balloon.position.y - balloonRadius)
        path.move(to: start)

        // Draw a smooth catmull-rom-style curve through all segment centres
        let points = [start] + ropeSegments.map { $0.position }
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            // Use a quadratic curve: control point is offset slightly sideways
            // so straight-hanging rope still renders cleanly
            let mid = CGPoint(x: (prev.x + curr.x) / 2,
                              y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
        }
        // Final segment to the last point
        if let last = points.last {
            path.addLine(to: last)
        }

        ropeDrawNode.path = path
    }

    override func didSimulatePhysics() {
        updateRopeDrawing()
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard enableBalloonTrail, balloon != nil else { return }
        
        // Spawn a small "ghost" circle periodically to form a trailing effect
        let interval: TimeInterval = 0.06
        if currentTime - lastTrailSpawnTime >= interval {
            lastTrailSpawnTime = currentTime
            spawnTrailDot()
        }
    }

    // MARK: - Collision

    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        // 1. Check for Balloon + PowerUp
        if collision == (PhysicsCategory.balloon | PhysicsCategory.powerUp) {
            let powerUpNode = (contact.bodyA.categoryBitMask == PhysicsCategory.powerUp) ? contact.bodyA.node : contact.bodyB.node
            powerUpNode?.removeFromParent()
            activateShield()
            return // Exit so we don't trigger game over logic
        }

        // 2. Check for Balloon + Arrow
        if collision == (PhysicsCategory.balloon | PhysicsCategory.arrow) {
            if isShielded {
                // Absorb the hit!
                isShielded = false
                shieldNode?.removeFromParent()
                
                // Remove the specific arrow that hit us
                let arrowNode = (contact.bodyA.categoryBitMask == PhysicsCategory.arrow) ? contact.bodyA.node : contact.bodyB.node
                arrowNode?.removeFromParent()
                updateScore() // Reward for "blocking"
            } else {
                // Game Over
                self.isPaused = true
                self.removeAllActions()
                self.onGameOver?(self.score)
            }
        }
    }
    
    // MARK: Create Power Up
    
    func spawnPowerUp(isSlowMo: Bool = false) {
        let mainColor: UIColor = isSlowMo ? .systemGreen : .systemBlue
        let container = SKNode()
        container.name = isSlowMo ? "slowmo" : "shield"
        
        // 1. The Outer Glow (Pulse)
        let glow = SKShapeNode(circleOfRadius: 20)
        glow.fillColor = mainColor.withAlphaComponent(0.3)
        glow.strokeColor = .clear
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.5, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])
        glow.run(SKAction.repeatForever(pulse))
        container.addChild(glow)
        
        // 2. The Core Orb
        let core = SKShapeNode(circleOfRadius: 12)
        core.fillColor = mainColor
        core.strokeColor = .white
        core.lineWidth = 2
        container.addChild(core)
        
        // 3. Floating "Orbits" (The Fancy Part)
        for i in 0..<2 {
            let orbit = SKShapeNode(rectOf: CGSize(width: 25, height: 25), cornerRadius: 5)
            orbit.strokeColor = .white
            orbit.lineWidth = 1
            orbit.alpha = 0.6
            orbit.zRotation = (CGFloat.pi / 4) * CGFloat(i)
            
            let rotate = SKAction.rotate(byAngle: i == 0 ? .pi : -.pi, duration: 2.0)
            orbit.run(SKAction.repeatForever(rotate))
            container.addChild(orbit)
        }
        
        // 4. Physics (Attached to the container)
        container.position = CGPoint(
            x: CGFloat.random(in: 100...size.width - 100),
            y: CGFloat.random(in: 100...size.height - 100)
        )
        
        let pBody = SKPhysicsBody(circleOfRadius: 18)
        pBody.isDynamic = false
        pBody.categoryBitMask = PhysicsCategory.powerUp
        pBody.contactTestBitMask = PhysicsCategory.balloon
        container.physicsBody = pBody
        
        addChild(container)
        
        // Floating movement
        let moveUp = SKAction.moveBy(x: 0, y: 15, duration: 1.5)
        moveUp.timingMode = .easeInEaseOut
        container.run(SKAction.repeatForever(SKAction.sequence([moveUp, moveUp.reversed()])))
        
        // Expiry
        container.run(SKAction.sequence([
            SKAction.wait(forDuration: 6.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
    
    // MARK: Active Shield
    
    func activateShield() {
        if isShielded { return }
        isShielded = true
        
        // 1. Main Outer Ring
        let shieldContainer = SKShapeNode(circleOfRadius: balloonRadius + 12)
        shieldContainer.strokeColor = .systemCyan
        shieldContainer.lineWidth = 2
        shieldContainer.alpha = 0.7
        
        // 2. The Tech Ring (Dashed look using segments)
        // We create a circle with "holes" in it manually
        let techPath = CGMutablePath()
        for angle in stride(from: 0, to: CGFloat.pi * 2, by: CGFloat.pi / 4) {
            techPath.addRelativeArc(center: .zero, radius: balloonRadius + 8,
                                   startAngle: angle, delta: CGFloat.pi / 8)
        }
        
        let innerRing = SKShapeNode(path: techPath)
        innerRing.strokeColor = .white
        innerRing.lineWidth = 1
        innerRing.lineCap = .round
        innerRing.glowWidth = 4.0
        shieldContainer.addChild(innerRing)
        
        // Spinning animation for the dashed part
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
        innerRing.run(SKAction.repeatForever(rotate))
        
        shieldNode = shieldContainer
        balloon.addChild(shieldContainer)
        
        // Breathing effect
        let breathe = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 1.0),
            SKAction.fadeAlpha(to: 0.7, duration: 1.0)
        ])
        shieldContainer.run(SKAction.repeatForever(breathe))
    }
    
    // Mark: - Active SlowMo

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if balloon.contains(location) {
            let dx = balloon.position.x - location.x
            let dy = balloon.position.y - location.y
            let angle = atan2(dy, dx)
            let speed: CGFloat = 450
            balloon.physicsBody?.velocity = CGVector(dx: cos(angle) * speed,
                                                     dy: sin(angle) * speed)
        }
    }
    
    func spawnPowerUp() {
        let powerUp = SKShapeNode(circleOfRadius: 15)
        powerUp.fillColor = .systemBlue
        powerUp.strokeColor = .white
        powerUp.lineWidth = 2
        
        // Spawn somewhere in the playable area
        let xPos = CGFloat.random(in: 100...size.width - 100)
        let yPos = CGFloat.random(in: 100...size.height - 100)
        powerUp.position = CGPoint(x: xPos, y: yPos)
        
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: 15)
        powerUp.physicsBody?.isDynamic = false // Static so it sits there
        powerUp.physicsBody?.categoryBitMask = PhysicsCategory.powerUp
        powerUp.physicsBody?.contactTestBitMask = PhysicsCategory.balloon
        powerUp.glowWidth = 4.0
        
        addChild(powerUp)
        
        // Make it pulse so it looks "alive"
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.5)
        let scaleDown = SKAction.scale(to: 0.8, duration: 0.5)
        powerUp.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])))
        
        // Remove if not picked up after 8 seconds
        powerUp.run(SKAction.sequence([SKAction.wait(forDuration: 8.0), SKAction.removeFromParent()]))
    }

    // Call this in didMove to start the cycle
    func startPowerUpSpawning() {
        let wait = SKAction.wait(forDuration: 10.0) // Spawn every 10 seconds
        let spawn = SKAction.run { [weak self] in self?.spawnPowerUp() }
        run(SKAction.repeatForever(SKAction.sequence([wait, spawn])))
    }

    // MARK: - Arrows

    func startArrowSpawning() {
        // Increased the wait slightly to account for the warning time
        let spawn = SKAction.run { [weak self] in self?.prepareArrow() }
        let wait  = SKAction.wait(forDuration: 1.5)
        run(SKAction.repeatForever(SKAction.sequence([wait, spawn])))
    }

    private func prepareArrow() {
        // 1. Determine spawn side and position
        let side = Int.random(in: 0...3)
        var start: CGPoint = .zero
        let margin: CGFloat = 40
        
        switch side {
        case 0:  start = CGPoint(x: -margin, y: CGFloat.random(in: 0...size.height))
        case 1:  start = CGPoint(x: size.width + margin, y: CGFloat.random(in: 0...size.height))
        case 2:  start = CGPoint(x: CGFloat.random(in: 0...size.width), y: -margin)
        default: start = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + margin)
        }

        // 2. Create a Warning Indicator
        let indicator = SKShapeNode(circleOfRadius: 12)
        indicator.fillColor = .red
        indicator.strokeColor = .white
        indicator.lineWidth = 2
        indicator.zPosition = 5
        
        // Clamp the indicator position so it's visible on the edge of the screen
        let indicatorPos = CGPoint(
            x: max(15, min(size.width - 15, start.x)),
            y: max(15, min(size.height - 15, start.y))
        )
        indicator.position = indicatorPos
        addChild(indicator)

        // 3. Animation: Blink indicator then spawn arrow
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        let repeatBlink = SKAction.repeat(blink, count: 3)
        
        let spawnAction = SKAction.run { [weak self] in
            indicator.removeFromParent()
            self?.fireArrow(from: start)
        }
        
        indicator.run(SKAction.sequence([repeatBlink, spawnAction]))
    }

    private func fireArrow(from start: CGPoint) {
        let arrowNode = makeArrowNode()
        arrowNode.position = start

        let pBody = SKPhysicsBody(rectangleOf: CGSize(width: 48, height: 9))
        pBody.isDynamic = true
        pBody.affectedByGravity = false
        pBody.categoryBitMask    = PhysicsCategory.arrow
        pBody.contactTestBitMask = PhysicsCategory.balloon
        pBody.collisionBitMask   = 0
        arrowNode.physicsBody = pBody
        addChild(arrowNode)

        let dx = balloon.position.x - start.x
        let dy = balloon.position.y - start.y
        let angle = atan2(dy, dx)
        arrowNode.zRotation = angle

        let speed: CGFloat = 250
        arrowNode.physicsBody?.velocity = CGVector(dx: cos(angle) * speed,
                                                   dy: sin(angle) * speed)

        // Cleanup and score
        let wait = SKAction.wait(forDuration: 5.0)
        let scoreCheck = SKAction.run { [weak self] in
            if arrowNode.parent != nil {
                arrowNode.removeFromParent()
                self?.updateScore()
            }
        }
        arrowNode.run(SKAction.sequence([wait, scoreCheck]))
    }

    /// Builds a parent SKNode containing a nicely drawn arrow pointing right (along +x).
    /// The arrow is centred so zRotation rotates it around its midpoint.
    private func makeArrowNode() -> SKNode {
        let container = SKNode()

        // --- dimensions ---
        let shaftLen:   CGFloat = 36   // length of the wooden shaft
        let shaftW:     CGFloat = 3    // shaft thickness
        let headLen:    CGFloat = 12   // arrowhead length
        let headW:      CGFloat = 9    // arrowhead half-width at base
        let fletchLen:  CGFloat = 10   // tail feather length
        let fletchW:    CGFloat = 5    // tail feather spread

        // Arrow points right: tip at x = shaftLen/2 + headLen/2 (approx)
        // We centre everything around x=0

        let totalLen = shaftLen + headLen
        let originX  = -totalLen / 2   // left edge of shaft

        // 1. Shaft (customisable colour)
        let shaftPath = CGMutablePath()
        shaftPath.addRect(CGRect(x: originX, y: -shaftW / 2,
                                 width: shaftLen, height: shaftW))
        let shaft = SKShapeNode(path: shaftPath)
        shaft.fillColor = arrowShaftColor
        shaft.strokeColor = arrowShaftColor.withAlphaComponent(0.8)
        shaft.lineWidth = 0.5
        container.addChild(shaft)

        // 2. Arrowhead (customisable colour)
        let tipX  = originX + totalLen
        let baseX = originX + shaftLen
        let headPath = CGMutablePath()
        headPath.move(to: CGPoint(x: tipX,  y: 0))
        headPath.addLine(to: CGPoint(x: baseX, y:  headW))
        headPath.addLine(to: CGPoint(x: baseX, y: -headW))
        headPath.closeSubpath()
        let head = SKShapeNode(path: headPath)
        head.fillColor = arrowHeadColor
        head.strokeColor = arrowHeadColor.withAlphaComponent(0.8)
        head.lineWidth = 0.5
        container.addChild(head)

        // 3. Fletching — two diagonal feather strokes at the tail
        let tailX = originX
        for sign: CGFloat in [-1, 1] {
            let fPath = CGMutablePath()
            fPath.move(to: CGPoint(x: tailX, y: 0))
            fPath.addLine(to: CGPoint(x: tailX + fletchLen,
                                      y: sign * fletchW))
            let feather = SKShapeNode(path: fPath)
            feather.strokeColor = arrowFeatherColor
            feather.lineWidth = 2
            feather.lineCap = .round
            container.addChild(feather)
        }

        return container
    }

    func spawnArrow() {
        let arrowNode = makeArrowNode()

        let side = Int.random(in: 0...3)
        var start: CGPoint = .zero
        switch side {
        case 0:  start = CGPoint(x: -40,             y: CGFloat.random(in: 0...size.height))
        case 1:  start = CGPoint(x: size.width + 40,  y: CGFloat.random(in: 0...size.height))
        case 2:  start = CGPoint(x: CGFloat.random(in: 0...size.width), y: -40)
        default: start = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + 40)
        }

        arrowNode.position = start

        // Physics body matches overall arrow length
        let pBody = SKPhysicsBody(rectangleOf: CGSize(width: 48, height: 9))
        pBody.isDynamic = true
        pBody.affectedByGravity = false
        pBody.categoryBitMask    = PhysicsCategory.arrow
        pBody.contactTestBitMask = PhysicsCategory.balloon
        pBody.collisionBitMask   = 0
        arrowNode.physicsBody = pBody
        addChild(arrowNode)

        let dx = balloon.position.x - start.x
        let dy = balloon.position.y - start.y
        let angle = atan2(dy, dx)
        arrowNode.zRotation = angle

        let speed: CGFloat = 250
        arrowNode.physicsBody?.velocity = CGVector(dx: cos(angle) * speed,
                                                   dy: sin(angle) * speed)

        let wait = SKAction.wait(forDuration: 5.0)
        let scoreCheck = SKAction.run { [weak self] in
            guard let self = self else { return }
            if arrowNode.parent != nil {
                arrowNode.removeFromParent()
                self.updateScore()
            }
        }
        arrowNode.run(SKAction.sequence([wait, scoreCheck]))
    }
    
    // MARK: - Appearance API
    
    func applyAppearance(
        balloonColor: UIColor,
        arrowShaftColor: UIColor,
        arrowHeadColor: UIColor,
        arrowFeatherColor: UIColor,
        backgroundColor: UIColor,
        enableTrail: Bool
    ) {
        self.balloonFillColor = balloonColor
        self.arrowShaftColor = arrowShaftColor
        self.arrowHeadColor = arrowHeadColor
        self.arrowFeatherColor = arrowFeatherColor
        self.sceneBackgroundColor = backgroundColor
        self.enableBalloonTrail = enableTrail
        
        // If the scene is already presented, update immediately
        self.backgroundColor = backgroundColor
        balloon?.fillColor = balloonColor
    }
    
    // MARK: - Trail
    
    private func spawnTrailDot() {
        guard let balloon = balloon else { return }
        
        let dot = SKShapeNode(circleOfRadius: 4)
        dot.fillColor = balloonFillColor.withAlphaComponent(0.4)
        dot.strokeColor = .clear
        dot.position = balloon.position
        dot.zPosition = -2
        addChild(dot)
        
        let fade = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        dot.run(SKAction.sequence([fade, remove]))
    }
}
