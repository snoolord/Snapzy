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

  private static var isPrompting = false
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
    explain: Bool = true,
    probe: (@MainActor () async -> Bool)? = nil,
    onFinish: @escaping @MainActor (Bool) -> Void = { _ in }
  ) {
    if explain {
      // Several enumeration paths can fire per hotkey press; only the first one prompts.
      guard !isPrompting, watchers.isEmpty else { return }
      isPrompting = true
      defer { isPrompting = false }
      guard confirmGrant(kind) else {
        onFinish(false)
        return
      }
    }
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

  /// Snapzy's own heads-up before System Settings opens, so the guide panel isn't a surprise.
  /// Not shown during onboarding, which already explains each permission.
  private static func confirmGrant(_ kind: PermissionKind) -> Bool {
    let (name, reason): (String, String) =
      switch kind {
      case .screenRecording: ("Screen Recording", "capture your screen")
      case .accessibility: ("Accessibility", "detect windows and control scrolling")
      case .inputMonitoring: ("Input Monitoring", "listen for your capture shortcuts")
      }
    let alert = NSAlert()
    alert.messageText = "Snapzy needs \(name) permission"
    alert.informativeText =
      "Snapzy needs this to \(reason). Click Grant Permission to open System Settings, then drag Snapzy from the guide into the list and turn it on."
    alert.addButton(withTitle: "Grant Permission")
    alert.addButton(withTitle: "Not Now")
    NSApp.activate(ignoringOtherApps: true)
    return alert.runModal() == .alertFirstButtonReturn
  }

  private static func stopWatchers() {
    watchers.forEach { $0.cancel() }
    watchers.removeAll()
  }
}
