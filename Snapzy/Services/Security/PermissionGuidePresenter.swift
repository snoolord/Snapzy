//
//  PermissionGuidePresenter.swift
//  Snapzy
//
//  Single entry point for the drag-to-grant PermissionGuide panel. Adds what the
//  package does not: a hard timeout, an optional out-of-process grant probe (for
//  permissions whose in-process status is cached stale), and bringing Snapzy back
//  to the front once the permission is granted.
//

import AppKit
import PermissionGuide

@MainActor
enum PermissionGuidePresenter {
  /// Give up and close the panel if the user wanders off.
  static let timeout: Duration = .seconds(180)
  private static let probeInterval: Duration = .milliseconds(1500)

  private static var watchers: [Task<Void, Never>] = []
  /// Set when the probe saw the grant before the package's own status check did.
  private static var probeGranted = false

  /// Presents the guide for `kind`. `onFinish(true)` fires after the permission is
  /// granted and Snapzy has been re-activated; `onFinish(false)` on timeout, dismissal
  /// or replacement by a newer guide.
  ///
  /// `probe` is polled while the guide is up and should return `true` once the grant
  /// is visible by any means the package cannot see (e.g. a child-process TCC probe).
  static func present(
    _ kind: PermissionKind,
    probe: (@MainActor () async -> Bool)? = nil,
    onFinish: @escaping @MainActor (Bool) -> Void = { _ in }
  ) {
    stopWatchers()
    probeGranted = false

    PermissionGuide.present(kind) { guideGranted in
      MainActor.assumeIsolated {
        stopWatchers()
        let granted = guideGranted || probeGranted
        probeGranted = false
        if granted { NSApp.activate(ignoringOtherApps: true) }
        onFinish(granted)
      }
    }

    watchers.append(
      Task {
        try? await Task.sleep(for: timeout)
        guard !Task.isCancelled else { return }
        PermissionGuide.dismiss()
      })

    if let probe {
      watchers.append(
        Task {
          while !Task.isCancelled {
            try? await Task.sleep(for: probeInterval)
            guard !Task.isCancelled else { return }
            if await probe() {
              guard !Task.isCancelled else { return }
              probeGranted = true
              PermissionGuide.dismiss()
              return
            }
          }
        })
    }
  }

  private static func stopWatchers() {
    watchers.forEach { $0.cancel() }
    watchers.removeAll()
  }
}
