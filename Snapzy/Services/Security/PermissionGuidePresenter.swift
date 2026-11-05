//
//  PermissionGuidePresenter.swift
//  Snapzy
//
//  Single entry point for the drag-to-grant PermissionGuide panel. Adds what the
//  package does not: a hard timeout, and bringing Snapzy back to the front once
//  the permission is granted.
//

import AppKit
import PermissionGuide

@MainActor
enum PermissionGuidePresenter {
  /// Give up and close the panel if the user wanders off.
  static let timeout: Duration = .seconds(180)

  private static var timeoutTask: Task<Void, Never>?

  /// Presents the guide for `kind`. `onFinish(true)` fires after the permission is
  /// granted and Snapzy has been re-activated; `onFinish(false)` on timeout, dismissal
  /// or replacement by a newer guide.
  static func present(_ kind: PermissionKind, onFinish: @escaping @MainActor (Bool) -> Void = { _ in }) {
    timeoutTask?.cancel()

    PermissionGuide.present(kind) { granted in
      MainActor.assumeIsolated {
        timeoutTask?.cancel()
        timeoutTask = nil
        if granted { NSApp.activate(ignoringOtherApps: true) }
        onFinish(granted)
      }
    }

    timeoutTask = Task {
      try? await Task.sleep(for: timeout)
      guard !Task.isCancelled else { return }
      PermissionGuide.dismiss()
    }
  }
}
