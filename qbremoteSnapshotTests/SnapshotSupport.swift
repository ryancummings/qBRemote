//
//  SnapshotSupport.swift
//  qbremoteSnapshotTests
//
//  Shared device matrix + assertion helper for visual-regression snapshot tests.
//
//  Snapshots are rendered through UIHostingController at fixed device geometries
//  and diffed against reference PNGs committed under __Snapshots__/.
//
//  Determinism rules (see also SnapshotFixtures):
//  - References are recorded and verified on ONE pinned simulator runtime.
//  - iPhone-geometry snapshots must run on an iPhone simulator and iPad
//    geometries on an iPad simulator, because some views branch on
//    `UIDevice.current.userInterfaceIdiom` (e.g. the stats capsule in
//    TorrentListView). `hostMatrix` picks the right set automatically.
//
//  Workflows:
//  - Verify: run the qbremoteSnapshotTests scheme; missing references are
//    recorded automatically (and fail once), existing ones are diffed.
//  - Re-record after an intentional UI change:
//    TEST_RUNNER_SNAPSHOT_RECORD=all xcodebuild test ...
//

import SnapshotTesting
import SwiftUI
import Testing
import UIKit
import XCTest

@testable import qbremote

// MARK: - Root Suite
//
// All snapshot suites nest inside this one so `.serialized` applies to the
// whole snapshot run. That matters because several tests pin shared state
// (`UserDefaults.standard`) before rendering; Swift Testing would otherwise
// interleave suites from different files in parallel.

@Suite(.serialized, .snapshots(record: SnapshotEnvironment.record))
enum SnapshotSuite {}

// MARK: - Environment

enum SnapshotEnvironment {

    /// Record mode: `.missing` auto-records absent references; export
    /// `TEST_RUNNER_SNAPSHOT_RECORD=all` to re-record everything.
    static var record: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "all" ? .all : .missing
    }

    /// Comparison tolerances for `Diffing.lsbTolerantImage` (the ONLY diffing
    /// the suite uses — see its doc comment for why the library's built-in
    /// `precision`/`perceptualPrecision` knobs are both unusable here).
    ///
    /// `maxChannelDelta` 6: sub-visible noise below this is ignored. Two
    /// sources produce it: CoreImage LSB dither (the AppLogo `luminanceToAlpha`
    /// chain, ±1/255 bimodally per process) and — the reason this isn't 1 —
    /// translucent-material blur (`.bar`, `.regularMaterial`) rendering
    /// differently across GPUs. CI on different Apple Silicon than the
    /// recording machine measured up to 3/255 across the filter-bar glass;
    /// 6 gives margin while staying far below any perceptible change. A real
    /// UI change shifts pixels by 50–255, so nothing visible slips through.
    ///
    /// `allowedOutlierPixels` 200: a cushion for isolated pixels that still
    /// exceed 6/255 from hardware differences. 200 px is a ~14×14 patch — far
    /// smaller than any real change (a single glyph is hundreds of pixels), so
    /// this does not blind the diff. Don't loosen these to pass a failing test.
    static let maxChannelDelta = 6
    static let allowedOutlierPixels = 200

    /// One-time neutralization of the test host app's own UI.
    ///
    /// Snapshots render with `drawHierarchyInKeyWindow`, and translucent
    /// regions (navigation-bar glass, materials) composite against whatever
    /// sits behind them in the window. The host app's live `RootView` is a
    /// moving target — tests that pin `isDemoMode` make it re-route, and demo
    /// mode animates. Replacing the root view controller with an inert opaque
    /// one gives every snapshot the same static backdrop and tears down the
    /// app's own polling/observers.
    @MainActor
    static let neutralizedHostApp: Void = {
        for window in allWindows {
            let inert = UIViewController()
            inert.view.backgroundColor = .black
            window.rootViewController = inert
            window.backgroundColor = .black
        }
    }()

    @MainActor
    static var allWindows: [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
    }

    /// Devices appropriate for the simulator this run is hosted on.
    @MainActor
    static var hostMatrix: [SnapshotDeviceConfig] {
        UIDevice.current.userInterfaceIdiom == .pad
            ? SnapshotDeviceConfig.iPads
            : SnapshotDeviceConfig.iPhones
    }

    /// Single device used for secondary state variants (empty/error states)
    /// and form-style sheets, where a full matrix adds bytes but no signal.
    @MainActor
    static var primaryDevice: SnapshotDeviceConfig {
        UIDevice.current.userInterfaceIdiom == .pad
            ? SnapshotDeviceConfig.iPadPro13
            : SnapshotDeviceConfig.iPhone17Pro
    }

    /// Pins every `@AppStorage`/UserDefaults flag that influences rendering to
    /// a known value. Call at the start of any test whose view reads defaults
    /// (the test host app's defaults persist between runs in the simulator).
    @MainActor
    static func pinUserDefaults(isDemoMode: Bool = false) {
        let defaults = UserDefaults.standard
        defaults.set(isDemoMode, forKey: "isDemoMode")
        defaults.set(false, forKey: "isDeveloperUnlocked")
        defaults.set(false, forKey: "showTipJarPopup")
        defaults.set(1, forKey: "appLaunchCount")
        defaults.set(AppTheme.system.rawValue, forKey: "themePreference")
    }
}

// MARK: - Device Matrix

/// A named render geometry for screen snapshots.
struct SnapshotDeviceConfig {
    let key: String
    let config: ViewImageConfig

    private static func traits(
        idiom: UIUserInterfaceIdiom,
        scale: CGFloat,
        horizontal: UIUserInterfaceSizeClass,
        vertical: UIUserInterfaceSizeClass
    ) -> UITraitCollection {
        UITraitCollection { mutable in
            mutable.userInterfaceIdiom = idiom
            mutable.displayScale = scale
            mutable.horizontalSizeClass = horizontal
            mutable.verticalSizeClass = vertical
        }
    }

    // MARK: iPhones (portrait)

    /// Smallest supported layout — catches truncation/wrapping regressions.
    static let iPhoneSE3 = SnapshotDeviceConfig(
        key: "iPhoneSE3",
        config: ViewImageConfig(
            safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0),
            size: CGSize(width: 375, height: 667),
            traits: traits(idiom: .phone, scale: 2, horizontal: .compact, vertical: .regular)
        )
    )

    static let iPhone17Pro = SnapshotDeviceConfig(
        key: "iPhone17Pro",
        config: ViewImageConfig(
            safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0),
            size: CGSize(width: 402, height: 874),
            traits: traits(idiom: .phone, scale: 3, horizontal: .compact, vertical: .regular)
        )
    )

    static let iPhone17ProMax = SnapshotDeviceConfig(
        key: "iPhone17ProMax",
        config: ViewImageConfig(
            safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0),
            size: CGSize(width: 440, height: 956),
            traits: traits(idiom: .phone, scale: 3, horizontal: .compact, vertical: .regular)
        )
    )

    // MARK: iPads (portrait)

    static let iPadPro11 = SnapshotDeviceConfig(
        key: "iPadPro11",
        config: ViewImageConfig(
            safeArea: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
            size: CGSize(width: 834, height: 1210),
            traits: traits(idiom: .pad, scale: 2, horizontal: .regular, vertical: .regular)
        )
    )

    static let iPadPro13 = SnapshotDeviceConfig(
        key: "iPadPro13",
        config: ViewImageConfig(
            safeArea: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
            size: CGSize(width: 1032, height: 1376),
            traits: traits(idiom: .pad, scale: 2, horizontal: .regular, vertical: .regular)
        )
    )

    static let iPhones = [iPhoneSE3, iPhone17Pro, iPhone17ProMax]
    static let iPads = [iPadPro11, iPadPro13]
}

// MARK: - LSB-Tolerant Diffing

extension Diffing where Value == UIImage {

    /// Deterministic image comparison for this suite.
    ///
    /// Both of the library's built-in comparison modes fail here:
    /// - `perceptualPrecision < 1` routes through CoreImage Lab-deltaE, which
    ///   is nondeterministic per run for the 16-bit Display-P3 captures the
    ///   key-window renderer produces (byte-identical images intermittently
    ///   reported ~4.5% mismatched).
    /// - Plain byte comparison trips on CoreImage LSB dither: the AppLogo
    ///   `luminanceToAlpha` chain flips ~10k pixels by exactly 1/255,
    ///   bimodally per process.
    ///
    /// So: normalize both images to 8-bit sRGB via CoreGraphics (deterministic
    /// CPU path), then require every channel delta ≤ `maxChannelDelta`, with
    /// up to `allowedOutlierPixels` isolated exceptions.
    // Immutable closures over constants; safe to share across the suite.
    nonisolated(unsafe) static let lsbTolerantImage = Diffing(
        toData: { $0.pngData() ?? Data() },
        fromData: { UIImage(data: $0) ?? UIImage() },
        diff: { reference, capture in
            guard let refPixels = rgba8Pixels(reference), let capPixels = rgba8Pixels(capture) else {
                return ("Snapshot comparison failed: could not decode image pixels.", attachments(reference, capture))
            }
            guard refPixels.width == capPixels.width, refPixels.height == capPixels.height else {
                let message = "Snapshot size \(capPixels.width)×\(capPixels.height) "
                    + "does not match reference size \(refPixels.width)×\(refPixels.height)."
                return (message, attachments(reference, capture))
            }
            // Fast path: bitwise identical.
            if refPixels.data == capPixels.data { return nil }

            var outliers = 0
            var maxDelta = 0
            refPixels.data.withUnsafeBufferPointer { ref in
                capPixels.data.withUnsafeBufferPointer { cap in
                    var index = 0
                    let count = ref.count
                    while index < count {
                        var pixelMax = 0
                        for channel in 0..<4 {
                            let delta = abs(Int(ref[index + channel]) - Int(cap[index + channel]))
                            if delta > pixelMax { pixelMax = delta }
                        }
                        if pixelMax > SnapshotEnvironment.maxChannelDelta { outliers += 1 }
                        if pixelMax > maxDelta { maxDelta = pixelMax }
                        index += 4
                    }
                }
            }
            if outliers <= SnapshotEnvironment.allowedOutlierPixels { return nil }
            let message = "Snapshot does not match reference: \(outliers) pixels differ by more than "
                + "\(SnapshotEnvironment.maxChannelDelta)/255 (max channel delta \(maxDelta), "
                + "allowed outliers \(SnapshotEnvironment.allowedOutlierPixels))."
            return (message, attachments(reference, capture))
        }
    )

    private static func rgba8Pixels(_ image: UIImage) -> (data: [UInt8], width: Int, height: Int)? {
        guard let cgImage = image.cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        return (buffer, width, height)
    }

    private static func attachments(_ reference: UIImage, _ capture: UIImage) -> [XCTAttachment] {
        let referenceAttachment = XCTAttachment(image: reference)
        referenceAttachment.name = "reference"
        let captureAttachment = XCTAttachment(image: capture)
        captureAttachment.name = "failure"
        return [referenceAttachment, captureAttachment]
    }
}

// MARK: - Assertion Helper

/// Snapshots `view` at every device geometry in `devices`, in light and dark
/// appearance. Reference names look like `<test>.<deviceKey>-dark.png`.
///
/// Views must be seeded to their final state before this call — either a
/// pre-populated `@Observable` view model or an injected pre-loaded one (see
/// `ServerPreferencesView`). Screens that only reach their target state via an
/// async `onAppear` load will NOT settle here: the capture is synchronous and
/// the snapshot run loop does not reliably drain a `Task`'s continuations.
@MainActor
func assertScreenSnapshot(
    _ view: some View,
    devices: [SnapshotDeviceConfig] = SnapshotEnvironment.hostMatrix,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    // Constant opaque backdrop behind translucent regions (see above).
    _ = SnapshotEnvironment.neutralizedHostApp

    // Freeze UIKit-driven animations (navigation-bar transitions, scroll-edge
    // effects) so captures never land mid-transition.
    UIView.setAnimationsEnabled(false)
    defer { UIView.setAnimationsEnabled(true) }

    let appearances: [(name: String, style: UIUserInterfaceStyle)] = [
        ("light", .light),
        ("dark", .dark),
    ]
    for device in devices {
        for appearance in appearances {
            let host = UIHostingController(rootView: view)
            host.overrideUserInterfaceStyle = appearance.style
            // drawHierarchyInKeyWindow is required for UIKit materials (.bar,
            // .regularMaterial) and lazy containers to render.
            var strategy: Snapshotting<UIViewController, UIImage> = .image(
                on: device.config,
                drawHierarchyInKeyWindow: true
            )
            strategy.diffing = .lsbTolerantImage
            assertSnapshot(
                of: host,
                as: strategy,
                named: "\(device.key)-\(appearance.name)",
                fileID: fileID,
                file: filePath,
                testName: testName,
                line: line,
                column: column
            )
            // Drain the run loop so the previous host view fully detaches
            // from the key window before the next capture — otherwise glass
            // regions of the next snapshot can composite over its remnants.
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        }
    }
}
