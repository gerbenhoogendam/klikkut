import AppKit
import QuartzCore

/// Laat confetti uit de muiscursor spuiten, in een doorzichtig venster boven alles.
@MainActor
final class ConfettiOverlay {
    static let shared = ConfettiOverlay()
    static let enabledKey = "confettiEnabled"

    private var bursts: [ConfettiBurst] = []

    func burst(at point: NSPoint = NSEvent.mouseLocation) {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main else { return }
        let burst = ConfettiBurst(screen: screen, origin: point)
        burst.onFinish = { [weak self, weak burst] in
            self?.bursts.removeAll { $0 === burst }
        }
        bursts.append(burst)
        burst.start()
    }
}

/// Eén salvo confetti. De snippers vertrekken heel hard, worden door luchtweerstand snel afgeremd
/// en dwarrelen daarna langzaam, wiegend en draaiend naar beneden.
@MainActor
private final class ConfettiBurst: NSObject {
    private struct Particle {
        let layer: CALayer
        var position: CGPoint
        var velocity: CGVector
        /// Luchtweerstand: hoe hoger, hoe sneller afgeremd en hoe langzamer het dwarrelen.
        let drag: CGFloat
        var angle: CGFloat
        let spin: CGFloat
        var flip: CGFloat
        let flipSpeed: CGFloat
        let swayAmplitude: CGFloat
        let swayFrequency: CGFloat
        let swayPhase: CGFloat
    }

    private static let particleCount = 160
    private static let gravity: CGFloat = 1040
    private static let lifetime: CFTimeInterval = 7
    private static let fadeDuration: CFTimeInterval = 1.5
    private static let colors: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen, .systemMint,
        .systemTeal, .systemBlue, .systemIndigo, .systemPurple, .systemPink,
    ]

    var onFinish: (() -> Void)?

    private let window: NSWindow
    private let container = CALayer()
    private var particles: [Particle] = []
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var age: CFTimeInterval = 0

    init(screen: NSScreen, origin: NSPoint) {
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.layer?.addSublayer(container)
        window.contentView = view
        container.frame = view.bounds

        super.init()

        let start = CGPoint(x: origin.x - screen.frame.minX, y: origin.y - screen.frame.minY)
        particles = (0..<Self.particleCount).map { _ in Self.makeParticle(at: start) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        particles.forEach { container.addSublayer($0.layer) }
        CATransaction.commit()
    }

    func start() {
        window.orderFrontRegardless()
        let link = window.contentView!.displayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private static func makeParticle(at start: CGPoint) -> Particle {
        let layer = CALayer()
        let color = colors.randomElement()!
        layer.backgroundColor = color.cgColor
        switch Int.random(in: 0..<10) {
        case 0..<6: // papiertje
            layer.bounds = CGRect(x: 0, y: 0, width: .random(in: 7...12), height: .random(in: 4...7))
            layer.cornerRadius = 1
        case 6..<8: // lint
            layer.bounds = CGRect(x: 0, y: 0, width: .random(in: 12...18), height: .random(in: 2.5...3.5))
            layer.cornerRadius = 1
        default: // rondje
            let d = CGFloat.random(in: 5...8)
            layer.bounds = CGRect(x: 0, y: 0, width: d, height: d)
            layer.cornerRadius = d / 2
        }
        layer.position = start

        // Een brede fontein omhoog, met af en toe een uitschieter.
        let direction = CGFloat.pi / 2 + .random(in: -1.35...1.35)
        let speed = 900 + 2300 * pow(CGFloat.random(in: 0...1), 0.7)

        return Particle(
            layer: layer,
            position: start,
            velocity: CGVector(dx: cos(direction) * speed, dy: sin(direction) * speed),
            drag: .random(in: 3.2...5.5),
            angle: .random(in: 0...(2 * .pi)),
            spin: .random(in: -6...6),
            flip: .random(in: 0...(2 * .pi)),
            flipSpeed: .random(in: 4...10),
            swayAmplitude: .random(in: 25...70),
            swayFrequency: .random(in: 1.5...3.5),
            swayPhase: .random(in: 0...(2 * .pi))
        )
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = min(CGFloat(now - (lastTimestamp ?? now)), 1.0 / 30)
        lastTimestamp = now
        age += CFTimeInterval(dt)

        let bounds = container.bounds
        let fadeStart = Self.lifetime - Self.fadeDuration
        let opacity = age > fadeStart ? Float(max(0, 1 - (age - fadeStart) / Self.fadeDuration)) : 1

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        particles.removeAll { p in
            let gone = p.position.y < bounds.minY - 30 || p.position.x < bounds.minX - 200 || p.position.x > bounds.maxX + 200
            if gone { p.layer.removeFromSuperlayer() }
            return gone
        }
        for i in particles.indices {
            var p = particles[i]
            // Lineaire luchtweerstand: eindsnelheid bij het vallen is gravity / drag (± 190–325 pt/s).
            let damping = exp(-p.drag * dt)
            p.velocity.dx *= damping
            p.velocity.dy = p.velocity.dy * damping - Self.gravity * dt
            let sway = p.swayAmplitude * sin(p.swayFrequency * CGFloat(age) + p.swayPhase)
            p.position.x += (p.velocity.dx + sway) * dt
            p.position.y += p.velocity.dy * dt
            p.angle += p.spin * dt
            p.flip += p.flipSpeed * dt

            var transform = CATransform3DMakeRotation(p.angle, 0, 0, 1)
            transform = CATransform3DRotate(transform, p.flip, 1, 0, 0)
            p.layer.position = p.position
            p.layer.transform = transform
            p.layer.opacity = opacity
            particles[i] = p
        }
        CATransaction.commit()

        if particles.isEmpty || age >= Self.lifetime {
            finish()
        }
    }

    private func finish() {
        displayLink?.invalidate()
        displayLink = nil
        window.orderOut(nil)
        window.close()
        onFinish?()
    }
}
