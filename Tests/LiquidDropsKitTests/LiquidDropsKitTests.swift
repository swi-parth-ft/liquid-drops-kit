import Testing
@testable import LiquidDropsKit

@Test func packageBuilds() {
    #expect(true)
}

@MainActor
@Test func materialStyleIsConfigurable() {
    let drop = LiquidDrop(title: "Hello", materialStyle: .thick)
    #expect(drop.materialStyle == .thick)
}
