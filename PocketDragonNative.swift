import AppKit

struct Particle {
    var kind: String
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: TimeInterval
    var color: NSColor
    var size: CGFloat
}

func now() -> TimeInterval {
    Date().timeIntervalSinceReferenceDate
}

func color(_ hex: String, alpha: CGFloat = 1.0) -> NSColor {
    var text = hex
    if text.first == "#" {
        text.removeFirst()
    }

    var value: UInt64 = 0
    Scanner(string: text).scanHexInt64(&value)
    let red = CGFloat((value >> 16) & 0xff) / 255.0
    let green = CGFloat((value >> 8) & 0xff) / 255.0
    let blue = CGFloat(value & 0xff) / 255.0
    return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

final class DragonWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class DragonView: NSView {
    weak var controller: DragonController?
    private let scale: CGFloat = 5
    private let ink = color("#4b3a3f")

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let controller else { return nil }
        let dragonRect = NSRect(x: 10, y: 48, width: 240, height: 198)
        let bubbleRect = NSRect(x: 28, y: 6, width: 204, height: 52)
        if dragonRect.contains(point) || (controller.bubbleUntil > now() && bubbleRect.contains(point)) {
            return self
        }
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let controller else { return }

        NSColor.clear.setFill()
        dirtyRect.fill()

        let bob = CGFloat(Int(round(sin(controller.phase * 1.8) * 2.5)))
        let run = CGFloat(sin(controller.phase * 2.6))
        let mouthOpen = controller.mouthUntil > now()

        drawShadow()
        drawDragon(bob: bob, run: run, mouthOpen: mouthOpen)
        drawParticles()

        if controller.bubbleUntil > now() {
            drawBubble(controller.bubbleText, mouthOpen: mouthOpen)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let controller else { return }
        if event.clickCount >= 2 {
            controller.feed()
            return
        }
        controller.startDrag(at: NSEvent.mouseLocation)
    }

    override func mouseDragged(with event: NSEvent) {
        controller?.drag(to: NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        controller?.finishDrag(at: NSEvent.mouseLocation)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let controller else { return }
        let menu = controller.makeMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func keyDown(with event: NSEvent) {
        guard let controller else { return }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "q":
            NSApp.terminate(nil)
        case "f":
            controller.feed()
        case "p":
            controller.pet()
        default:
            if event.keyCode == 53 {
                NSApp.terminate(nil)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    private func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: NSColor, ox: CGFloat, oy: CGFloat) {
        guard let controller else { return }
        let drawX: CGFloat
        if controller.facing < 0 {
            drawX = bounds.width - (ox + (x + w) * scale)
        } else {
            drawX = ox + x * scale
        }
        let rect = NSRect(x: drawX, y: oy + y * scale, width: w * scale, height: h * scale)
        fill.setFill()
        rect.fill()
    }

    private func blocks(_ rects: [(CGFloat, CGFloat, CGFloat, CGFloat)], _ fill: NSColor, ox: CGFloat, oy: CGFloat) {
        for rect in rects {
            block(rect.0, rect.1, rect.2, rect.3, fill, ox: ox, oy: oy)
        }
    }

    private func drawShadow() {
        color("#52636b", alpha: 0.35).setFill()
        NSBezierPath(ovalIn: NSRect(x: 58, y: 224, width: 146, height: 16)).fill()
        color("#6f858c", alpha: 0.28).setFill()
        NSBezierPath(ovalIn: NSRect(x: 86, y: 226, width: 92, height: 10)).fill()
    }

    private func drawDragon(bob: CGFloat, run: CGFloat, mouthOpen: Bool) {
        guard let controller else { return }

        let ox: CGFloat = 15
        let oy: CGFloat = 52 + bob
        let blue = color("#67d8f4")
        let blueDark = color("#249fc9")
        let blueLight = color("#a8f0ff")
        let wing = color("#43c2e7")
        let wingLight = color("#83e4ff")
        let yellow = color("#ffdc75")
        let yellowDark = color("#f6a844")
        let pink = color("#ff8aa0")
        let red = color("#ff686e")
        let redDark = color("#ef3e43")
        let white = NSColor.white
        let eye = color("#33272d")
        let flap: CGFloat = sin(controller.phase * 3.8) > 0 ? -1 : 0
        let footA: CGFloat = run > 0.1 ? 1 : 0
        let footB: CGFloat = run < -0.1 ? 1 : 0

        blocks([(34, 29, 7, 4), (39, 26, 3, 4), (41, 22, 3, 5), (42, 18, 2, 5), (40, 17, 4, 2)], ink, ox: ox, oy: oy)
        blocks([(35, 29, 5, 3), (39, 27, 2, 3), (41, 23, 2, 4), (42, 19, 1, 4)], blueDark, ox: ox, oy: oy)
        block(36, 30, 1, 1, pink, ox: ox, oy: oy)
        block(39, 31, 1, 1, pink, ox: ox, oy: oy)
        block(42, 18, 2, 1, red, ox: ox, oy: oy)

        blocks([(2, 18 + flap, 4, 3), (1, 21 + flap, 5, 4), (4, 16 + flap, 3, 3), (5, 25 + flap, 3, 2)], ink, ox: ox, oy: oy)
        blocks([(3, 19 + flap, 3, 2), (2, 22 + flap, 4, 2), (5, 17 + flap, 1, 2), (5, 24 + flap, 2, 1)], wing, ox: ox, oy: oy)
        block(3, 20 + flap, 2, 1, wingLight, ox: ox, oy: oy)
        blocks([(40, 18 + flap, 4, 3), (40, 21 + flap, 5, 4), (38, 16 + flap, 3, 3), (38, 25 + flap, 3, 2)], ink, ox: ox, oy: oy)
        blocks([(41, 19 + flap, 3, 2), (41, 22 + flap, 4, 2), (39, 17 + flap, 1, 2), (39, 24 + flap, 2, 1)], wing, ox: ox, oy: oy)
        block(41, 20 + flap, 2, 1, wingLight, ox: ox, oy: oy)

        blocks([(15, 28, 18, 8), (16, 36, 5, 2), (27, 36, 5, 2), (13, 29, 5, 3), (31, 29, 5, 3)], ink, ox: ox, oy: oy)
        block(17, 29, 14, 7, blueDark, ox: ox, oy: oy)
        block(20, 29, 8, 8, yellow, ox: ox, oy: oy)
        block(20, 31, 8, 1, color("#ffe796"), ox: ox, oy: oy)
        block(21, 34, 6, 1, yellowDark, ox: ox, oy: oy)
        block(17, 36 + footA, 4, 1, blueLight, ox: ox, oy: oy)
        block(28, 36 + footB, 4, 1, blueLight, ox: ox, oy: oy)
        block(14, 29, 3, 2, blue, ox: ox, oy: oy)
        block(32, 29, 3, 2, blue, ox: ox, oy: oy)

        blocks([(7, 5, 4, 2), (8, 7, 5, 2), (10, 9, 4, 2), (12, 11, 3, 2), (35, 5, 4, 2), (33, 7, 5, 2), (32, 9, 4, 2), (31, 11, 3, 2)], ink, ox: ox, oy: oy)
        blocks([(8, 5, 3, 2), (9, 7, 4, 2), (11, 9, 3, 2), (13, 11, 1, 1), (35, 5, 3, 2), (33, 7, 4, 2), (32, 9, 3, 2), (32, 11, 1, 1)], yellow, ox: ox, oy: oy)
        block(12, 10, 2, 1, yellowDark, ox: ox, oy: oy)
        block(32, 10, 2, 1, yellowDark, ox: ox, oy: oy)

        blocks([(20, 0, 7, 2), (19, 2, 8, 3), (18, 5, 6, 4), (19, 9, 9, 2), (24, 4, 3, 6)], ink, ox: ox, oy: oy)
        blocks([(21, 1, 5, 2), (20, 3, 5, 3), (19, 6, 5, 4), (20, 9, 6, 1)], red, ox: ox, oy: oy)
        block(24, 3, 2, 7, redDark, ox: ox, oy: oy)
        block(22, 1, 2, 1, color("#ff9a9f"), ox: ox, oy: oy)

        blocks([(10, 9, 28, 1), (8, 10, 32, 2), (7, 12, 34, 4), (6, 16, 36, 8), (7, 24, 34, 3), (9, 27, 30, 2), (12, 29, 24, 1)], ink, ox: ox, oy: oy)
        block(11, 10, 26, 2, blueLight, ox: ox, oy: oy)
        block(8, 12, 32, 4, blue, ox: ox, oy: oy)
        block(7, 16, 34, 8, blue, ox: ox, oy: oy)
        block(9, 24, 30, 3, blueDark, ox: ox, oy: oy)
        block(12, 27, 24, 1, blueDark, ox: ox, oy: oy)
        block(10, 13, 12, 3, color("#84e6fb"), ox: ox, oy: oy)
        block(24, 10, 1, 5, blueDark, ox: ox, oy: oy)
        block(26, 10, 1, 4, blueDark, ox: ox, oy: oy)
        block(22, 12, 1, 3, color("#37afd5"), ox: ox, oy: oy)

        if controller.affection > 86 {
            block(11, 22, 4, 2, pink, ox: ox, oy: oy)
            block(33, 22, 4, 2, pink, ox: ox, oy: oy)
        }

        if sin(controller.phase * 0.7) > 0.985 {
            block(13, 18, 7, 1, ink, ox: ox, oy: oy)
            block(29, 18, 7, 1, ink, ox: ox, oy: oy)
        } else {
            blocks([(13, 16, 7, 7), (29, 16, 7, 7)], ink, ox: ox, oy: oy)
            block(14, 17, 5, 5, eye, ox: ox, oy: oy)
            block(30, 17, 5, 5, eye, ox: ox, oy: oy)
            block(15, 17, 2, 2, white, ox: ox, oy: oy)
            block(31, 17, 2, 2, white, ox: ox, oy: oy)
            block(18, 21, 1, 1, white, ox: ox, oy: oy)
            block(34, 21, 1, 1, white, ox: ox, oy: oy)
        }

        if mouthOpen {
            block(22, 23, 5, 3, ink, ox: ox, oy: oy)
            block(23, 24, 3, 2, color("#ff8fb1"), ox: ox, oy: oy)
            block(22, 23, 1, 1, white, ox: ox, oy: oy)
            block(26, 23, 1, 1, white, ox: ox, oy: oy)
        } else {
            blocks([(20, 23, 1, 1), (21, 24, 2, 1), (23, 23, 2, 1), (25, 24, 2, 1), (27, 23, 1, 1)], ink, ox: ox, oy: oy)
            block(22, 25, 1, 1, white, ox: ox, oy: oy)
            block(26, 25, 1, 1, white, ox: ox, oy: oy)
        }

        block(20, 22, 2, 1, color("#36a7cb"), ox: ox, oy: oy)
        block(27, 22, 2, 1, color("#36a7cb"), ox: ox, oy: oy)
    }

    private func drawParticles() {
        guard let controller else { return }
        for particle in controller.particles {
            let size = particle.size * max(0.35, min(1.0, CGFloat(particle.life)))
            particle.color.setFill()
            if particle.kind == "heart" {
                NSBezierPath(ovalIn: NSRect(x: particle.x - size, y: particle.y - size, width: size, height: size)).fill()
                NSBezierPath(ovalIn: NSRect(x: particle.x, y: particle.y - size, width: size, height: size)).fill()
                let path = NSBezierPath()
                path.move(to: NSPoint(x: particle.x - size, y: particle.y - size * 0.35))
                path.line(to: NSPoint(x: particle.x + size, y: particle.y - size * 0.35))
                path.line(to: NSPoint(x: particle.x, y: particle.y + size * 1.1))
                path.close()
                path.fill()
            } else if particle.kind == "crumb" {
                NSBezierPath(ovalIn: NSRect(x: particle.x - size, y: particle.y - size * 0.7, width: size * 2, height: size * 1.4)).fill()
            } else {
                let path = NSBezierPath()
                for index in 0..<10 {
                    let radius = index % 2 == 0 ? size : size * 0.45
                    let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
                    let point = NSPoint(x: particle.x + cos(angle) * radius, y: particle.y + sin(angle) * radius)
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.line(to: point)
                    }
                }
                path.close()
                path.fill()
            }
        }
    }

    private func drawBubble(_ text: String, mouthOpen: Bool) {
        let rect = NSRect(x: 30, y: 8, width: 200, height: 42)
        color("#fffaf2").setFill()
        ink.setStroke()
        let bubble = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        bubble.lineWidth = 3
        bubble.fill()
        bubble.stroke()

        let tailX: CGFloat = controller?.facing ?? 1 > 0 ? 145 : 115
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: tailX - 9, y: rect.maxY - 1))
        tail.line(to: NSPoint(x: tailX + 8, y: rect.maxY - 1))
        tail.line(to: NSPoint(x: tailX + ((controller?.facing ?? 1) > 0 ? 17 : -17), y: rect.maxY + 16))
        tail.close()
        color("#fffaf2").setFill()
        tail.fill()
        tail.lineWidth = 3
        tail.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Avenir Next", size: 16) ?? NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: ink,
            .paragraphStyle: paragraph
        ]
        let textRect = rect.insetBy(dx: 10, dy: 9).offsetBy(dx: 0, dy: mouthOpen ? -1 : 0)
        NSString(string: text).draw(in: textRect, withAttributes: attrs)
    }
}

final class DragonController: NSObject {
    let width: CGFloat = 260
    let height: CGFloat = 250
    var window: DragonWindow!
    var view: DragonView!
    var timer: Timer?

    var x: CGFloat = 100
    var y: CGFloat = 100
    var vx: CGFloat = 1.8
    var vy: CGFloat = 0
    var targetX: CGFloat = 100
    var targetY: CGFloat = 100
    var facing: CGFloat = 1
    var phase: CGFloat = 0
    var lastTick = now()
    var nextDecision = now()
    var nextChirp = now() + Double.random(in: 12...22)
    var nextBoundsCheck = now()
    var screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)

    var bubbleText = "hi hi!"
    var bubbleUntil = now() + 3.5
    var mouthUntil: TimeInterval = 0
    var hunger: CGFloat = 18
    var affection: CGFloat = 76
    var particles: [Particle] = []

    var soundOn = true
    var voiceOn = false
    private var dragStartMouse = NSPoint.zero
    private var dragStartOrigin = NSPoint.zero
    private var wasDragged = false

    func show() {
        screenFrame = NSScreen.main?.visibleFrame ?? screenFrame
        x = CGFloat.random(in: (screenFrame.minX + 30)...max(screenFrame.minX + 31, screenFrame.maxX - width - 30))
        y = max(screenFrame.minY + 70, screenFrame.minY + 80)
        targetX = x
        targetY = y

        window = DragonWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false

        view = DragonView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view.controller = self
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        chooseTarget()
        timer = Timer.scheduledTimer(timeInterval: 1.0 / 30.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @objc func tick() {
        let current = now()
        let dt = min(0.08, max(0.001, current - lastTick))
        lastTick = current
        phase += CGFloat(dt * 7.0)
        refreshBounds(current)
        updateNeeds(dt)
        maybeChirp(current)
        updateMotion(current, dt)
        updateParticles(dt)
        view.needsDisplay = true
    }

    func refreshBounds(_ current: TimeInterval) {
        if current < nextBoundsCheck { return }
        screenFrame = NSScreen.main?.visibleFrame ?? screenFrame
        nextBoundsCheck = current + 2
    }

    func updateNeeds(_ dt: TimeInterval) {
        hunger = min(100, hunger + CGFloat(dt) * 1.05)
        affection = max(0, affection - CGFloat(dt) * 0.35)
    }

    func maybeChirp(_ current: TimeInterval) {
        if current < nextChirp { return }
        let message: String
        if hunger > 68 {
            message = ["snack pls?", "tiny snack?", "feed me?"].randomElement()!
        } else if affection < 36 {
            message = ["pet me pls?", "snoot pat?", "tap me!"].randomElement()!
        } else {
            message = ["chirp chirp!", "hi hi!", "got snacks?", "pet me?"].randomElement()!
        }
        chirp(message, seconds: 5.2)
        nextChirp = current + Double.random(in: 26...66)
    }

    func updateMotion(_ current: TimeInterval, _ dt: TimeInterval) {
        if current >= nextDecision {
            chooseTarget()
        }

        let dx = targetX - x
        let dy = targetY - y
        vx += max(-0.42, min(0.42, dx * 0.006))
        vy += max(-0.35, min(0.35, dy * 0.005))
        vx *= 0.90
        vy *= 0.90

        let speed = hypot(vx, vy)
        let maxSpeed: CGFloat = hunger < 75 ? 4.0 : 2.8
        if speed > maxSpeed {
            let ratio = maxSpeed / speed
            vx *= ratio
            vy *= ratio
        }
        if abs(vx) > 0.15 {
            facing = vx > 0 ? 1 : -1
        }

        x += vx * CGFloat(dt / 0.033)
        y += vy * CGFloat(dt / 0.033)
        keepOnScreen()
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func chooseTarget() {
        let left = screenFrame.minX + 12
        let right = max(left, screenFrame.maxX - width - 12)
        let bottom = screenFrame.minY + 30
        let top = max(bottom, screenFrame.maxY - height - 12)

        targetX = CGFloat.random(in: left...right)
        if Bool.random() {
            targetY = CGFloat.random(in: bottom...min(top, bottom + 120))
        } else {
            targetY = CGFloat.random(in: bottom...top)
        }
        nextDecision = now() + Double.random(in: 2.5...7.0)
    }

    func keepOnScreen() {
        let minX = screenFrame.minX + 8
        let maxX = max(minX, screenFrame.maxX - width - 8)
        let minY = screenFrame.minY + 8
        let maxY = max(minY, screenFrame.maxY - height - 8)

        if x < minX || x > maxX { vx *= -0.65 }
        if y < minY || y > maxY { vy *= -0.65 }
        x = max(minX, min(maxX, x))
        y = max(minY, min(maxY, y))
    }

    func updateParticles(_ dt: TimeInterval) {
        var kept: [Particle] = []
        for var particle in particles {
            particle.x += particle.vx * CGFloat(dt / 0.033)
            particle.y += particle.vy * CGFloat(dt / 0.033)
            particle.vy += 0.025
            particle.life -= dt
            if particle.life > 0 {
                kept.append(particle)
            }
        }
        particles = kept
    }

    func startDrag(at point: NSPoint) {
        dragStartMouse = point
        dragStartOrigin = window.frame.origin
        wasDragged = false
    }

    func drag(to point: NSPoint) {
        let dx = point.x - dragStartMouse.x
        let dy = point.y - dragStartMouse.y
        if abs(dx) > 4 || abs(dy) > 4 {
            wasDragged = true
        }
        x = dragStartOrigin.x + dx
        y = dragStartOrigin.y + dy
        vx = 0
        vy = 0
        keepOnScreen()
        targetX = x
        targetY = y
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func finishDrag(at point: NSPoint) {
        let moved = wasDragged || hypot(point.x - dragStartMouse.x, point.y - dragStartMouse.y) > 5
        if moved {
            bubble("whee!", seconds: 2.2)
            burst(kind: "spark", count: 9)
        } else {
            pet()
        }
    }

    @objc func pet() {
        affection = min(100, affection + 28)
        hunger = min(100, hunger + 1.5)
        bubble(["prrrp!", "snoot pat!", "best human", "again!"].randomElement()!, seconds: 3.0)
        mouthUntil = now() + 0.9
        burst(kind: "heart", count: 8)
        playSound("Purr")
    }

    @objc func feed() {
        hunger = max(0, hunger - 42)
        affection = min(100, affection + 12)
        bubble(["nom nom!", "berry!!!", "tiny feast", "cronch!"].randomElement()!, seconds: 3.2)
        mouthUntil = now() + 1.4
        burst(kind: "crumb", count: 12)
        playSound("Pop")
    }

    func chirp(_ text: String, seconds: TimeInterval = 4.0) {
        bubble(text, seconds: seconds)
        mouthUntil = now() + 1.2
        burst(kind: "spark", count: 5)
        playSound(["Ping", "Glass", "Tink"].randomElement()!)
        if voiceOn {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            task.arguments = ["-v", "Bells", text.replacingOccurrences(of: "?", with: "")]
            try? task.run()
        }
    }

    func bubble(_ text: String, seconds: TimeInterval) {
        bubbleText = text
        bubbleUntil = now() + seconds
    }

    func burst(kind: String, count: Int) {
        let palette: [NSColor]
        if kind == "heart" {
            palette = [color("#ff5a7a"), color("#ff8aa0"), color("#ffd1dc")]
        } else if kind == "crumb" {
            palette = [color("#f8d56b"), color("#f39c4a"), color("#fff3a6")]
        } else {
            palette = [color("#7df6d2"), color("#f8d56b"), color("#8d85ff")]
        }

        let originX: CGFloat = facing > 0 ? 148 : 112
        let originY: CGFloat = 164
        for _ in 0..<count {
            let angle = CGFloat.random(in: -CGFloat.pi * 0.95 ... -CGFloat.pi * 0.05)
            let speed = CGFloat.random(in: 1.4...3.4)
            particles.append(
                Particle(
                    kind: kind,
                    x: originX + CGFloat.random(in: -12...12),
                    y: originY + CGFloat.random(in: -10...12),
                    vx: cos(angle) * speed,
                    vy: sin(angle) * speed,
                    life: TimeInterval.random(in: 0.7...1.25),
                    color: palette.randomElement()!,
                    size: CGFloat.random(in: 4...8)
                )
            )
        }
    }

    func playSound(_ name: String) {
        if !soundOn { return }
        let candidates = [
            "/System/Library/Sounds/\(name).aiff",
            "/System/Library/Sounds/Ping.aiff",
            "/System/Library/Sounds/Pop.aiff"
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            NSSound(contentsOfFile: path, byReference: true)?.play()
            return
        }
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Pet the snoot", action: #selector(pet), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Feed a meteor berry", action: #selector(feed), keyEquivalent: "").target = self
        menu.addItem(.separator())

        let sound = NSMenuItem(title: "Sound chirps", action: #selector(toggleSound), keyEquivalent: "")
        sound.target = self
        sound.state = soundOn ? .on : .off
        menu.addItem(sound)

        let voice = NSMenuItem(title: "Voice chirps", action: #selector(toggleVoice), keyEquivalent: "")
        voice.target = self
        voice.state = voiceOn ? .on : .off
        menu.addItem(voice)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
        return menu
    }

    @objc func toggleSound() {
        soundOn.toggle()
    }

    @objc func toggleVoice() {
        voiceOn.toggle()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: DragonController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = DragonController()
        self.controller = controller
        controller.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
