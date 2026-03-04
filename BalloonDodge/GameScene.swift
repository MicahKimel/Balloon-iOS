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
    
    // Story
    private var storyLabel: SKLabelNode!
    private var highestStoryMilestone: Int = 0
    private var familyScenePlayed: Bool = false
    
    // Appearance configuration (set from SwiftUI)
    private var balloonFillColor: UIColor = .systemRed
    private var arrowShaftColor: UIColor = UIColor(red: 0.82, green: 0.65, blue: 0.40, alpha: 1)
    private var arrowHeadColor: UIColor = UIColor(red: 0.75, green: 0.75, blue: 0.80, alpha: 1)
    private var arrowFeatherColor: UIColor = UIColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1)
    private var sceneBackgroundColor: UIColor = .black
    private var enableBalloonTrail: Bool = false
    private var isFamilyMode: Bool = false
    private var familyBalloons: [SKShapeNode] = []
    
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
        if !isFamilyMode {
            // In individual mode we use the full physics rope.
            setupRope()
        }
        setupScoreLabel()
        setupStoryLabel()
        startArrowSpawning()
        startPowerUpSpawning()
        
        // If we started this run explicitly in family mode, spawn the family immediately (no overlay)
        if isFamilyMode {
            playFamilyFoundScene()
        }
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
        updateStoryIfNeeded()
        
        let defaults = UserDefaults.standard
        if score >= 10 {
            defaults.set(true, forKey: "achievement_score10")
        }
        if score >= 50 {
            defaults.set(true, forKey: "achievement_score50")
        }
        if score >= 100 {
            defaults.set(true, forKey: "achievement_score100")
        }
    }
    
    // MARK: - Story
    
    private func setupStoryLabel() {
        storyLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        storyLabel.text = "The arrows rise, jealous of your color… Quick tap the balloon and Fly, Fly, be free!"
        storyLabel.fontSize = 16
        storyLabel.fontColor = UIColor(white: 0.9, alpha: 0.5)
        storyLabel.horizontalAlignmentMode = .center
        storyLabel.verticalAlignmentMode = .top
        storyLabel.preferredMaxLayoutWidth = size.width - 40
        storyLabel.numberOfLines = 0
        storyLabel.position = CGPoint(x: frame.midX, y: frame.minY + 80)
        storyLabel.zPosition = 10
        addChild(storyLabel)
    }
    
    private func updateStoryIfNeeded() {
        // Milestones where the story changes (mapped to rising tension, ending at family discovery)
        let milestones: [Int] = [1, 10, 20, 30, 40, 50, 100]
        guard let next = milestones.last(where: { score >= $0 && $0 > highestStoryMilestone }) else {
            return
        }
        
        highestStoryMilestone = next
        let text = storyText(for: next)
        storyLabel.text = text
        appendStoryLog(text: text)
        
        if next == 100 {
            // Only the first time we ever cross this threshold should unlock family + dramatic scene
            let defaults = UserDefaults.standard
            let alreadyUnlocked = defaults.bool(forKey: "familyModeUnlocked")
            if !alreadyUnlocked {
                unlockFamilyAndMode()
                // Current run transitions into family mode from here on
                isFamilyMode = true
                clearMainRope()
                playFamilyFoundScene()
            }
        }
    }
    
    private func storyText(for milestone: Int) -> String {
        switch milestone {
        case 1:
            return "You slip past the first jealous arrow. The sky remembers your color."
        case 10:
            return "Ten arrows missed. Whispers rise: maybe the last balloon can’t be popped."
        case 20:
            return "The arrows weave tighter patterns, stung by every second you survive."
        case 30:
            return "You dance between volleys. Their jealousy turns to obsession."
        case 40:
            return "The air hums with tension. Somewhere below, quivers run empty."
        case 50:
            return "You’ve outlived every party you were meant to decorate."
        case 100:
            return "A rumor floats on the wind: perhaps you were never truly alone…"
        default:
            return storyLabel?.text ?? ""
        }
    }
    
    private func unlockFamilyAndMode() {
        // Story-wise, this is where the last balloon finds the rest.
        let defaults = UserDefaults.standard
        
        // Unlock every balloon skin (ids 0...4 as defined in AppearanceConfig)
        let allBalloonIDs = Array(0...4)
        let encoded = allBalloonIDs.map(String.init).joined(separator: ",")
        defaults.set(encoded, forKey: "unlockedBalloonStyleIDs")
        
        // Unlock family play mode in SwiftUI
        defaults.set(true, forKey: "familyModeUnlocked")
        defaults.set(true, forKey: "achievement_familyUnlocked")
    }

    private func appendStoryLog(text: String) {
        let defaults = UserDefaults.standard
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let stamp = formatter.string(from: Date())
        let line = "\(stamp) – \(text)"
        
        let existing = defaults.string(forKey: "storyLog") ?? ""
        let updated: String
        if existing.isEmpty {
            updated = line
        } else {
            updated = existing + "\n" + line
        }
        defaults.set(updated, forKey: "storyLog")
    }

    private func playFamilyFoundScene() {
        guard !familyScenePlayed else { return }
        familyScenePlayed = true
        
        // Dim the world
        let overlay = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.75), size: size)
        overlay.position = CGPoint(x: frame.midX, y: frame.midY)
        overlay.zPosition = 50
        addChild(overlay)
        
        // Title text
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "YOU WERE NEVER ALONE"
        title.fontSize = 26
        title.fontColor = .white
        title.position = CGPoint(x: frame.midX, y: frame.midY + 40)
        title.zPosition = 51
        addChild(title)
        
        // Subtitle
        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Regular")
        subtitle.text = "Your family of balloons rises to meet you in the clear sky."
        subtitle.fontSize = 16
        subtitle.fontColor = UIColor(white: 0.9, alpha: 0.9)
        subtitle.preferredMaxLayoutWidth = size.width - 60
        subtitle.numberOfLines = 0
        subtitle.horizontalAlignmentMode = .center
        subtitle.verticalAlignmentMode = .center
        subtitle.position = CGPoint(x: frame.midX, y: frame.midY - 10)
        subtitle.zPosition = 51
        addChild(subtitle)
        
        // Spawn a ring of colorful family balloons around the main one
        let colors: [UIColor] = [
            .systemRed, .systemBlue, .systemGreen, .systemOrange,
            .systemPurple, .systemPink, .systemTeal, .systemYellow
        ]
        let radius = balloonRadius * 0.9
        let ringRadius: CGFloat = 120
        let center = CGPoint(x: frame.midX, y: frame.midY)
        
        for (index, color) in colors.enumerated() {
            let angle = (CGFloat(index) / CGFloat(colors.count)) * (.pi * 2)
            let x = center.x + cos(angle) * ringRadius
            let y = center.y + sin(angle) * ringRadius
            
            let node = SKShapeNode(circleOfRadius: radius)
            node.fillColor = color
            node.strokeColor = .white
            node.lineWidth = 2
            node.position = CGPoint(x: x, y: y)
            node.alpha = 0.0
            node.setScale(0.5)
            
            let body = SKPhysicsBody(circleOfRadius: radius)
            body.isDynamic = true
            body.affectedByGravity = false
            body.categoryBitMask    = PhysicsCategory.balloon
            body.contactTestBitMask = PhysicsCategory.arrow
            body.collisionBitMask   = PhysicsCategory.edge
            node.physicsBody = body
            
            addChild(node)
            familyBalloons.append(node)
            addString(to: node)
            
            let delay = SKAction.wait(forDuration: 0.05 * Double(index))
            let appear = SKAction.group([
                SKAction.fadeIn(withDuration: 0.2),
                SKAction.scale(to: 1.0, duration: 0.2)
            ])
            node.run(SKAction.sequence([delay, appear]))
        }
        
        // Pulse the main balloon
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        balloon.run(pulse)
        
        // Fade out overlay and text after a moment
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        overlay.run(SKAction.sequence([wait, fadeOut, .removeFromParent()]))
        title.run(SKAction.sequence([wait, fadeOut, .removeFromParent()]))
        subtitle.run(SKAction.sequence([wait, fadeOut, .removeFromParent()]))
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
        
        familyBalloons = [balloon]
        
        // Only show per-balloon strings in family mode. In individual mode we rely
        // on the main physics rope for the tether visual.
        if isFamilyMode {
            addString(to: balloon)
        }
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

    private func clearMainRope() {
        // Remove physics rope segments and clear the draw node.
        for seg in ropeSegments {
            seg.removeFromParent()
        }
        ropeSegments.removeAll()
        ropeDrawNode.path = nil
    }

    // Rope-style visual string attached to a balloon (reuses the rope path idea)
    private func addString(to node: SKShapeNode) {
        let path = CGMutablePath()

        // Start just below the balloon
        let start = CGPoint(x: 0, y: -balloonRadius)
        path.move(to: start)

        // Build a few control points to create a gentle rope-like curve downward
        let totalLength = balloonRadius * 2.4
        let segments = 4
        var points: [CGPoint] = [start]
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let y = -balloonRadius - totalLength * t
            // small horizontal sway left/right as we go down
            let x: CGFloat = (i % 2 == 0) ? -3 : 3
            points.append(CGPoint(x: x, y: y))
        }

        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let mid = CGPoint(x: (prev.x + curr.x) / 2,
                              y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
        }
        if let last = points.last {
            path.addLine(to: last)
        }

        let string = SKShapeNode(path: path)
        string.strokeColor = .white
        string.lineWidth = 1.5
        string.zPosition = -1
        node.addChild(string)
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
                // Determine which balloon was hit
                let hitBalloonNode = (contact.bodyA.categoryBitMask == PhysicsCategory.balloon
                                      ? contact.bodyA.node
                                      : contact.bodyB.node) as? SKShapeNode
                
                if isFamilyMode, let hit = hitBalloonNode {
                    if let idx = familyBalloons.firstIndex(of: hit) {
                        familyBalloons.remove(at: idx)
                    }
                    
                    let pop = SKAction.sequence([
                        SKAction.scale(to: 1.3, duration: 0.08),
                        SKAction.fadeOut(withDuration: 0.15),
                        .removeFromParent()
                    ])
                    hit.run(pop)
                    
                    // Lose only when all balloons are gone
                    if familyBalloons.allSatisfy({ $0.parent == nil }) {
                        self.isPaused = true
                        self.removeAllActions()
                        self.onGameOver?(self.score)
                    }
                } else {
                    // Individual mode: one hit = game over
                    self.isPaused = true
                    self.removeAllActions()
                    self.onGameOver?(self.score)
                }
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
        
        // Achievement: first shield collected
        UserDefaults.standard.set(true, forKey: "achievement_firstShield")
        
        // 1. Template for the shield ring
        let shieldTemplate = SKShapeNode(circleOfRadius: balloonRadius + 12)
        shieldTemplate.strokeColor = .systemCyan
        shieldTemplate.lineWidth = 2
        shieldTemplate.alpha = 0.7
        
        // 2. The Tech Ring (Dashed look using segments)
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
        shieldTemplate.addChild(innerRing)
        
        // Spinning animation for the dashed part
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
        innerRing.run(SKAction.repeatForever(rotate))
        
        // Apply shield to either the single balloon or the whole family
        let targets: [SKShapeNode] = isFamilyMode ? familyBalloons : (balloon != nil ? [balloon] : [])
        for node in targets {
            let shield = shieldTemplate.copy() as! SKShapeNode
            shield.name = "shield"
            node.addChild(shield)
            
            if node === balloon {
                shieldNode = shield
            }
            
            let breathe = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 1.0),
                SKAction.fadeAlpha(to: 0.7, duration: 1.0)
            ])
            shield.run(SKAction.repeatForever(breathe))
        }
    }
    
    // Mark: - Active SlowMo

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // In family mode, allow tapping any remaining balloon
        if isFamilyMode {
            for node in familyBalloons where node.parent != nil {
                if node.contains(location) {
                    let dx = node.position.x - location.x
                    let dy = node.position.y - location.y
                    let angle = atan2(dy, dx)
                    let speed: CGFloat = 450
                    node.physicsBody?.velocity =
                        CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
                    return
                }
            }
        }
        
        // Fallback: single main balloon
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

    private func currentTargetBalloon() -> SKShapeNode? {
        if isFamilyMode {
            return familyBalloons.first(where: { $0.parent != nil })
        }
        return balloon
    }

    private func fireArrow(from start: CGPoint) {
        guard let target = currentTargetBalloon() else { return }

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
        
        let dx = target.position.x - start.x
        let dy = target.position.y - start.y
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
        enableTrail: Bool,
        familyMode: Bool
    ) {
        self.balloonFillColor = balloonColor
        self.arrowShaftColor = arrowShaftColor
        self.arrowHeadColor = arrowHeadColor
        self.arrowFeatherColor = arrowFeatherColor
        self.sceneBackgroundColor = backgroundColor
        self.enableBalloonTrail = enableTrail
        self.isFamilyMode = familyMode
        
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
