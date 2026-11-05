//
//  RecordingPreRecordKey.swift
//  Snapzy
//
//  Pure classification for pre-record toolbar keyboard shortcuts.
//

import AppKit

/// Keyboard handling for the pre-record toolbar (before recording starts).
enum RecordingPreRecordKey {
  enum StartAction: Equatable {
    case video
    case gif
    /// Record video, then open the result in the video editor.
    case studio
  }

  /// Return / keypad Enter starts a video recording; Option+Return starts a GIF, Shift+Return records then opens the editor.
  /// Any other modifier combination is ignored. Fixed keys (not remappable), mirroring
  /// the area-selection Return conventions.
  static func startAction(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> StartAction? {
    guard keyCode == 36 || keyCode == 76 else { return nil } // Return, keypad Enter
    switch modifierFlags.intersection([.command, .option, .control, .shift]) {
    case []: return .video
    case .option: return .gif
    case .shift: return .studio
    default: return nil
    }
  }
}
