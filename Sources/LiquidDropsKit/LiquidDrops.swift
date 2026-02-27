import SwiftUI
import Combine
import UIKit

@MainActor
public struct LiquidDrop: Identifiable, ExpressibleByStringLiteral {
    public init(
        title: String,
        titleNumberOfLines: Int = 1,
        subtitle: String? = nil,
        subtitleNumberOfLines: Int = 1,
        icon: UIImage? = nil,
        action: Action? = nil,
        position: Position = .top,
        duration: Duration = .recommended,
        animationStyle: AnimationStyle = .default,
        accessibility: Accessibility? = nil,
        effectStyle: EffectStyle = .regular,
        glassTint: Color? = nil
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = UUID()
        self.title = trimmedTitle
        self.titleNumberOfLines = titleNumberOfLines
        if let subtitle {
            let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            self.subtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle
        } else {
            self.subtitle = nil
        }
        self.subtitleNumberOfLines = subtitleNumberOfLines
        self.icon = icon
        self.action = action
        self.position = position
        self.duration = duration
        self.animationStyle = animationStyle
        self.effectStyle = effectStyle
        self.glassTint = glassTint
        self.accessibility = accessibility
            ?? .init(message: [trimmedTitle, self.subtitle].compactMap { $0 }.joined(separator: ", "))
    }

    public init(stringLiteral title: String) {
        self.init(title: title)
    }

    public let id: UUID
    public var title: String
    public var titleNumberOfLines: Int
    public var subtitle: String?
    public var subtitleNumberOfLines: Int
    public var icon: UIImage?
    public var action: Action?
    public var position: Position
    public var duration: Duration
    public var animationStyle: AnimationStyle
    public var accessibility: Accessibility
    public var effectStyle: EffectStyle
    public var glassTint: Color?
}

public extension LiquidDrop {
    enum Position: Equatable {
        case top
        case bottom
    }
}

public extension LiquidDrop {
    enum EffectStyle: Equatable {
        case regular
        case clear
    }
}

public extension LiquidDrop {
    struct AnimationStyle: Equatable {
        public init(coming: AnimationCurve = .spring, going: AnimationCurve = .easeInOut) {
            self.coming = coming
            self.going = going
        }

        public var coming: AnimationCurve
        public var going: AnimationCurve

        public static let `default` = Self()
    }
}

public extension LiquidDrop {
    enum AnimationCurve: Equatable {
        case spring
        case snappy
        case bouncy
        case smooth
        case easeInOut
        case linear
    }
}

public extension LiquidDrop {
    enum Duration: Equatable, ExpressibleByFloatLiteral {
        case recommended
        case nolimit
        case seconds(TimeInterval)

        public init(floatLiteral value: TimeInterval) {
            self = .seconds(value)
        }

        var value: TimeInterval? {
            switch self {
            case .recommended:
                return 2.0
            case .nolimit:
                return nil
            case let .seconds(custom):
                return abs(custom)
            }
        }
    }
}

public extension LiquidDrop {
    struct Action {
        public init(icon: UIImage? = nil, handler: @escaping () -> Void) {
            self.icon = icon
            self.handler = handler
        }

        public var icon: UIImage?
        public var handler: () -> Void
    }
}

public extension LiquidDrop {
    struct Accessibility: ExpressibleByStringLiteral {
        public init(message: String) {
            self.message = message
        }

        public init(stringLiteral message: String) {
            self.message = message
        }

        public let message: String
    }
}

@MainActor
public final class LiquidDrops: ObservableObject {
    public typealias DropHandler = (LiquidDrop) -> Void

    public static let shared = LiquidDrops()

    public static func show(_ drop: LiquidDrop) {
        shared.show(drop)
    }

    public static func hideCurrent() {
        shared.hideCurrent()
    }

    public static func hideAll() {
        shared.hideAll()
    }

    public static var willShowDrop: DropHandler? {
        get { shared.willShowDrop }
        set { shared.willShowDrop = newValue }
    }

    public static var didShowDrop: DropHandler? {
        get { shared.didShowDrop }
        set { shared.didShowDrop = newValue }
    }

    public static var willDismissDrop: DropHandler? {
        get { shared.willDismissDrop }
        set { shared.willDismissDrop = newValue }
    }

    public static var didDismissDrop: DropHandler? {
        get { shared.didDismissDrop }
        set { shared.didDismissDrop = newValue }
    }

    public init(delayBetweenDrops: TimeInterval = 0.5) {
        self.delayBetweenDrops = delayBetweenDrops
    }

    public var willShowDrop: DropHandler?
    public var didShowDrop: DropHandler?
    public var willDismissDrop: DropHandler?
    public var didDismissDrop: DropHandler?

    @Published fileprivate var currentDrop: LiquidDrop?
    @Published fileprivate var visibility: CGFloat = 0

    fileprivate func beginInteraction() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }

    fileprivate func endInteraction() {
        queueAutoHideIfNeeded()
    }

    public func show(_ drop: LiquidDrop) {
        queue.append(drop)
        presentNextIfNeeded()
    }

    public func hideCurrent() {
        guard let currentDrop else { return }
        hide(dropID: currentDrop.id, animated: true)
    }

    public func hideAll() {
        queue.removeAll()
        hideCurrent()
    }

    private let delayBetweenDrops: TimeInterval

    private var queue: [LiquidDrop] = []
    private var autoHideTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?

    private func presentNextIfNeeded() {
        guard currentDrop == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()

        currentDrop = next
        visibility = 0

        willShowDrop?(next)
        withAnimation(animation(forEntrance: next.animationStyle.coming)) {
            visibility = 1
        }
        didShowDrop?(next)

        UIAccessibility.post(notification: .announcement, argument: next.accessibility.message)
        queueAutoHideIfNeeded()
    }

    private func queueAutoHideIfNeeded() {
        autoHideTask?.cancel()
        guard let currentDrop else { return }
        guard let duration = currentDrop.duration.value else { return }

        autoHideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await self?.hide(dropID: currentDrop.id, animated: true)
        }
    }

    private func hide(dropID: UUID, animated: Bool) {
        guard let currentDrop, currentDrop.id == dropID else { return }

        autoHideTask?.cancel()
        autoHideTask = nil

        willDismissDrop?(currentDrop)
        let dismissAnimation = animation(forExit: currentDrop.animationStyle.going)
        let dismissDuration = animationDuration(forExit: currentDrop.animationStyle.going)

        if animated {
            withAnimation(dismissAnimation) {
                visibility = 0
            }
        } else {
            visibility = 0
        }

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            guard let self else { return }

            if animated {
                try? await Task.sleep(for: .seconds(dismissDuration + 0.02))
            }

            guard let stillCurrent = self.currentDrop, stillCurrent.id == dropID else { return }
            self.currentDrop = nil
            self.didDismissDrop?(stillCurrent)

            try? await Task.sleep(for: .seconds(self.delayBetweenDrops))
            guard !Task.isCancelled else { return }
            self.presentNextIfNeeded()
        }
    }

    private func animation(forEntrance curve: LiquidDrop.AnimationCurve) -> Animation {
        switch curve {
        case .spring:
            return .spring(duration: 0.72, bounce: 0.15)
        case .snappy:
            return .snappy(duration: 0.44, extraBounce: 0.12)
        case .bouncy:
            return .bouncy(duration: 0.7, extraBounce: 0.18)
        case .smooth:
            return .smooth(duration: 0.45)
        case .easeInOut:
            return .easeInOut(duration: 0.45)
        case .linear:
            return .linear(duration: 0.42)
        }
    }

    private func animation(forExit curve: LiquidDrop.AnimationCurve) -> Animation {
        switch curve {
        case .spring:
            return .spring(duration: 0.32, bounce: 0.05)
        case .snappy:
            return .snappy(duration: 0.24, extraBounce: 0)
        case .bouncy:
            return .bouncy(duration: 0.34, extraBounce: 0.08)
        case .smooth:
            return .smooth(duration: 0.26)
        case .easeInOut:
            return .easeInOut(duration: 0.26)
        case .linear:
            return .linear(duration: 0.22)
        }
    }

    private func animationDuration(forExit curve: LiquidDrop.AnimationCurve) -> TimeInterval {
        switch curve {
        case .spring:
            return 0.32
        case .snappy:
            return 0.24
        case .bouncy:
            return 0.34
        case .smooth, .easeInOut:
            return 0.26
        case .linear:
            return 0.22
        }
    }
}

public extension View {
    func liquidDropsHost() -> some View {
        modifier(LiquidDropsHostModifier())
    }
}

private struct LiquidDropsHostModifier: ViewModifier {
    @StateObject private var drops = LiquidDrops.shared

    func body(content: Content) -> some View {
        ZStack {
            content
            LiquidDropsOverlay(drops: drops)
                .zIndex(999)
        }
    }
}

private struct LiquidDropsOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var drops: LiquidDrops
    @State private var dragOffset: CGFloat = 0
    @State private var isGestureDismissing = false
    @State private var islandBeatHapticsTask: Task<Void, Never>?
    @State private var adaptiveForeground: Color = .white
    @State private var topCardBaseSize: CGSize = CGSize(width: 280, height: 56)

    var body: some View {
        GeometryReader { proxy in
            if let drop = drops.currentDrop {
                container(for: drop, safeArea: proxy.safeAreaInsets, canvasSize: proxy.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: drop.id) { _, _ in
                        dragOffset = 0
                        isGestureDismissing = false
                        islandBeatHapticsTask?.cancel()
                        islandBeatHapticsTask = nil
                    }
                    .task(id: drop.id) {
                        scheduleIslandBeatHaptics(for: drop, canvasSize: proxy.size)
                        for attempt in 0..<6 {
                            guard drops.currentDrop?.id == drop.id else { break }
                            updateAdaptiveForeground(for: drop, safeArea: proxy.safeAreaInsets, canvasSize: proxy.size)
                            if attempt < 5 {
                                try? await Task.sleep(for: .milliseconds(120))
                            }
                        }
                    }
            }
        }
        .allowsHitTesting(drops.currentDrop != nil)
        .ignoresSafeArea()
        .onChange(of: drops.currentDrop?.id) { _, newValue in
            if newValue == nil {
                islandBeatHapticsTask?.cancel()
                islandBeatHapticsTask = nil
            }
        }
    }

    @ViewBuilder
    private func container(for drop: LiquidDrop, safeArea: EdgeInsets, canvasSize: CGSize) -> some View {
        let topInset = resolvedTopInset(from: safeArea)
        let bottomInset = resolvedBottomInset(from: safeArea)
        let t = clamped(drops.visibility, to: 0...1)

        switch drop.position {
        case .top:
            let islandFrame = dynamicIslandFrame(topInset: topInset, canvasWidth: canvasSize.width)
            let showIslandBeat = shouldShowIslandBeat(canvasSize: canvasSize)
            ZStack(alignment: .top) {
                if showIslandBeat {
                    islandLaunchCapsule(islandFrame: islandFrame, progress: t)
                }
                card(for: drop, cornerRadius: topCornerRadius(for: t, islandFrame: islandFrame))
                    .readSize { size in
                        guard size.width > 0, size.height > 0 else { return }
                        topCardBaseSize = size
                        updateAdaptiveForeground(for: drop, safeArea: safeArea, canvasSize: canvasSize)
                    }
                    .scaleEffect(
                        x: topScale(for: t, islandFrame: islandFrame, cardSize: topCardBaseSize).width,
                        y: topScale(for: t, islandFrame: islandFrame, cardSize: topCardBaseSize).height,
                        anchor: .top
                    )
                    .offset(y: topY(for: t, topInset: topInset, islandFrame: islandFrame) + dragOffset)
                    .shadow(
                        color: .black.opacity(0.18 * topShadowAmount(for: t)),
                        radius: 20 * topShadowAmount(for: t),
                        y: 9 * topShadowAmount(for: t)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .bottom:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card(for: drop)
                    .readSize { size in
                        guard size.width > 0, size.height > 0 else { return }
                        topCardBaseSize = size
                        updateAdaptiveForeground(for: drop, safeArea: safeArea, canvasSize: canvasSize)
                    }
                    .padding(.bottom, bottomInset + 8)
                    .offset(y: lerp(from: 170, to: 0, t: drops.visibility) + dragOffset)
                    .shadow(color: .black.opacity(0.18), radius: 20, y: 9)
            }
        }
    }

    private func shouldShowIslandBeat(canvasSize: CGSize) -> Bool {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let isPortrait = canvasSize.height >= canvasSize.width
        return isPhone && isPortrait
    }

    private func scheduleIslandBeatHaptics(for drop: LiquidDrop, canvasSize: CGSize) {
        islandBeatHapticsTask?.cancel()
        islandBeatHapticsTask = nil

        guard drop.position == .top else { return }
        guard shouldShowIslandBeat(canvasSize: canvasSize) else { return }

        islandBeatHapticsTask = Task { @MainActor in
            let first = UIImpactFeedbackGenerator(style: .medium)
            first.prepare()
            first.impactOccurred(intensity: 0.95)

            try? await Task.sleep(for: .milliseconds(130))
            guard !Task.isCancelled else { return }

            let second = UIImpactFeedbackGenerator(style: .soft)
            second.prepare()
            second.impactOccurred(intensity: 0.7)
        }
    }

    private func islandLaunchCapsule(islandFrame: CGRect, progress: CGFloat) -> some View {
        let t = clamped(progress, to: 0...1)
        return Capsule(style: .continuous)
            .fill(.black)
            .frame(width: islandFrame.width, height: islandFrame.height)
            .offset(y: islandFrame.minY + islandBeatYOffset(for: t))
            .scaleEffect(islandBeatScale(for: t))
            .opacity(islandBeatOpacity(for: t))
            .allowsHitTesting(false)
    }

    private func resolvedTopInset(from safeArea: EdgeInsets) -> CGFloat {
        let windowTop = keyWindowSafeAreaInsets.top
        let statusBarTop = statusBarHeight
        return max(safeArea.top, windowTop, statusBarTop, 44)
    }

    private func resolvedBottomInset(from safeArea: EdgeInsets) -> CGFloat {
        let windowBottom = keyWindowSafeAreaInsets.bottom
        return max(safeArea.bottom, windowBottom, 0)
    }

    private var keyWindowSafeAreaInsets: UIEdgeInsets {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)

        guard !windows.isEmpty else { return .zero }
        return windows
            .map(\.safeAreaInsets)
            .max { $0.top < $1.top } ?? .zero
    }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .compactMap { $0.statusBarManager?.statusBarFrame.height }
            .max() ?? 0
    }

    private func dynamicIslandFrame(topInset: CGFloat, canvasWidth: CGFloat) -> CGRect {
        let isiPhone = UIDevice.current.userInterfaceIdiom == .phone
        let hasLikelyIsland = isiPhone && topInset >= 54

        let width: CGFloat = hasLikelyIsland ? 126 : 108
        let height: CGFloat = hasLikelyIsland ? 37 : 32
        let centeredTop = max(0, (topInset - height) * 0.5)
        let topY: CGFloat = hasLikelyIsland
            ? centeredTop
            : max(8, centeredTop)

        return CGRect(
            x: (canvasWidth - width) / 2,
            y: topY,
            width: width,
            height: height
        )
    }

    private func topScale(for progress: CGFloat, islandFrame: CGRect, cardSize: CGSize) -> CGSize {
        let t = clamped(progress, to: 0...1)
        let expandCutoff: CGFloat = 0.42
        let safeWidth = max(cardSize.width, 1)
        let safeHeight = max(cardSize.height, 1)

        let startWidthScale = islandFrame.width / safeWidth
        let startHeightScale = islandFrame.height / safeHeight

        if t < expandCutoff {
            let phase = clamped(t / expandCutoff, to: 0...1)
            return CGSize(
                width: lerp(from: startWidthScale, to: 1.08, t: phase),
                height: lerp(from: startHeightScale, to: 1.05, t: phase)
            )
        } else {
            let phase = clamped((t - expandCutoff) / (1 - expandCutoff), to: 0...1)
            return CGSize(
                width: lerp(from: 1.08, to: 1, t: phase),
                height: lerp(from: 1.05, to: 1, t: phase)
            )
        }
    }

    private func topY(for progress: CGFloat, topInset: CGFloat, islandFrame: CGRect) -> CGFloat {
        let t = clamped(progress, to: 0...1)
        let start = islandFrame.minY
        let end = topInset + 8
        let mid = min(end, start + 18)
        let cutoff: CGFloat = 0.42

        if t < cutoff {
            let phase = clamped(t / cutoff, to: 0...1)
            return lerp(from: start, to: mid, t: phase)
        } else {
            let phase = clamped((t - cutoff) / (1 - cutoff), to: 0...1)
            return lerp(from: mid, to: end, t: phase)
        }
    }

    private func topCornerRadius(for progress: CGFloat, islandFrame: CGRect) -> CGFloat {
        let t = clamped(progress, to: 0...1)
        let cutoff: CGFloat = 0.42
        let startRadius = islandFrame.height * 0.5

        if t < cutoff {
            let phase = clamped(t / cutoff, to: 0...1)
            return lerp(from: startRadius, to: 28, t: phase)
        } else {
            let phase = clamped((t - cutoff) / (1 - cutoff), to: 0...1)
            return lerp(from: 28, to: 24, t: phase)
        }
    }

    private func topShadowAmount(for progress: CGFloat) -> CGFloat {
        clamped((progress - 0.12) / 0.88, to: 0...1)
    }

    private func islandBeatScale(for progress: CGFloat) -> CGFloat {
        let t = clamped(progress, to: 0...1)

        if t < 0.06 {
            return 1
        } else if t < 0.28 {
            let phase = clamped((t - 0.06) / 0.22, to: 0...1)
            return 1 + (0.17 * sin(phase * .pi))
        } else if t < 0.46 {
            let phase = clamped((t - 0.28) / 0.18, to: 0...1)
            return 1 + (0.09 * sin(phase * .pi))
        } else {
            return 1
        }
    }

    private func islandBeatYOffset(for progress: CGFloat) -> CGFloat {
        let t = clamped(progress, to: 0...1)

        if t < 0.06 {
            return 0
        } else if t < 0.28 {
            let phase = clamped((t - 0.06) / 0.22, to: 0...1)
            return -3.2 * sin(phase * .pi)
        } else if t < 0.46 {
            let phase = clamped((t - 0.28) / 0.18, to: 0...1)
            return -1.8 * sin(phase * .pi)
        } else {
            return 0
        }
    }

    private func islandBeatOpacity(for progress: CGFloat) -> CGFloat {
        let t = clamped(progress, to: 0...1)
        return 1 - clamped((t - 0.18) / 0.44, to: 0...1)
    }

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private func updateAdaptiveForeground(for drop: LiquidDrop, safeArea: EdgeInsets, canvasSize: CGSize) {
        let topInset = resolvedTopInset(from: safeArea)
        let bottomInset = resolvedBottomInset(from: safeArea)

        let points = adaptiveSamplePoints(
            for: drop,
            topInset: topInset,
            bottomInset: bottomInset,
            canvasSize: canvasSize
        )
        let luminances = points.compactMap(sampleWindowLuminance(at:))

        guard !luminances.isEmpty else {
            adaptiveForeground = fallbackAdaptiveForeground
            return
        }

        let luminance = luminances.reduce(0, +) / CGFloat(luminances.count)
        let resolvedColor: Color = luminance > 0.58 ? .black : .white
        withAnimation(.easeInOut(duration: 0.18)) {
            adaptiveForeground = resolvedColor
        }
    }

    private func adaptiveSamplePoints(
        for drop: LiquidDrop,
        topInset: CGFloat,
        bottomInset: CGFloat,
        canvasSize: CGSize
    ) -> [CGPoint] {
        let centerX = canvasSize.width * 0.5
        let offsetX = min(max(canvasSize.width * 0.18, 24), 52)
        let estimatedHeight = max(topCardBaseSize.height, drop.subtitle == nil ? 56 : 64)

        let sampleY: CGFloat
        switch drop.position {
        case .top:
            sampleY = topInset + 8 + estimatedHeight + 14
        case .bottom:
            sampleY = canvasSize.height - bottomInset - 8 - estimatedHeight - 14
        }

        return [
            CGPoint(x: centerX - offsetX, y: sampleY),
            CGPoint(x: centerX, y: sampleY),
            CGPoint(x: centerX + offsetX, y: sampleY)
        ]
    }

    private var fallbackAdaptiveForeground: Color {
        colorScheme == .light ? .black : .white
    }

    private func sampleWindowLuminance(at point: CGPoint) -> CGFloat? {
        guard let window = keyWindow else { return nil }

        let sampledPoint = CGPoint(
            x: min(max(point.x, 0), max(window.bounds.width - 1, 0)),
            y: min(max(point.y, 0), max(window.bounds.height - 1, 0))
        )

        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.translateBy(x: -sampledPoint.x, y: -sampledPoint.y)
        window.layer.render(in: context)

        let r = CGFloat(pixel[0]) / 255
        let g = CGFloat(pixel[1]) / 255
        let b = CGFloat(pixel[2]) / 255
        return (0.299 * r) + (0.587 * g) + (0.114 * b)
    }

    private func card(for drop: LiquidDrop, cornerRadius: CGFloat = 24) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return HStack(spacing: 14) {
            if let icon = drop.icon {
                Image(uiImage: icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(adaptiveForeground)
            }

            VStack(spacing: drop.subtitle == nil ? 0 : 2) {
                Text(drop.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(drop.titleNumberOfLines)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(adaptiveForeground)

                if let subtitle = drop.subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(adaptiveForeground.opacity(0.78))
                        .lineLimit(drop.subtitleNumberOfLines)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionIcon = drop.action?.icon {
                Button {
                    drop.action?.handler()
                } label: {
                    Image(uiImage: actionIcon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .frame(width: 32, height: 32)
                        .background(adaptiveForeground.opacity(0.16), in: Circle())
                        .foregroundStyle(adaptiveForeground)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, drop.subtitle == nil ? 14 : 10)
        .padding(.horizontal, 14)
        .background {
            if drop.effectStyle == .clear {
                shape
                    .fill(.clear)
                    .glassEffect(
                        .clear.tint((drop.glassTint ?? .cyan).opacity(0.14)),
                        in: shape
                    )
            } else {
                shape
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint((drop.glassTint ?? .cyan).opacity(0.2)),
                        in: shape
                    )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(shape)
        .onTapGesture {
            if let action = drop.action, action.icon == nil {
                action.handler()
            }
        }
        .gesture(dragGesture(for: drop))
        .padding(.horizontal, 20)
    }

    private func dragGesture(for drop: LiquidDrop) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !isGestureDismissing else { return }
                drops.beginInteraction()

                switch drop.position {
                case .top:
                    if value.translation.height < 0 {
                        if value.translation.height <= -18 {
                            isGestureDismissing = true
                            dragOffset = 0
                            drops.hideCurrent()
                            return
                        }
                        dragOffset = value.translation.height
                    } else {
                        dragOffset = value.translation.height * 0.2
                    }
                case .bottom:
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    } else {
                        dragOffset = value.translation.height * 0.2
                    }
                }
            }
            .onEnded { value in
                guard !isGestureDismissing else {
                    isGestureDismissing = false
                    return
                }
                let projected = value.predictedEndTranslation.height
                let shouldDismiss: Bool

                switch drop.position {
                case .top:
                    shouldDismiss = projected < -78
                case .bottom:
                    shouldDismiss = projected > 78
                }

                if shouldDismiss {
                    drops.hideCurrent()
                } else {
                    withAnimation(.spring(duration: 0.34, bounce: 0.2)) {
                        dragOffset = 0
                    }
                    drops.endInteraction()
                }
            }
    }
}

private func lerp(from: CGFloat, to: CGFloat, t: CGFloat) -> CGFloat {
    from + (to - from) * t
}

private func clamped(_ value: CGFloat, to limits: ClosedRange<CGFloat>) -> CGFloat {
    min(max(value, limits.lowerBound), limits.upperBound)
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private extension View {
    func readSize(_ onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: SizePreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

#Preview("Bubble") {
    LiquidDropBubblePreview()
}

private struct LiquidDropBubblePreview: View {
    @StateObject private var drops = LiquidDrops()

    private let sampleDrop = LiquidDrop(
        title: "Copied to clipboard",
        subtitle: "Paste anywhere",
        icon: UIImage(systemName: "doc.on.doc.fill"),
        glassTint: .clear
    )

    var body: some View {
        ZStack {
            Color.black
            .ignoresSafeArea()

            LiquidDropsOverlay(drops: drops)
        }
        .onAppear {
            drops.currentDrop = sampleDrop
            drops.visibility = 1
        }
    }
}
