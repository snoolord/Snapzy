//
//  RecordingPreRecordKeyTests.swift
//  SnapzyTests
//
//  Classification coverage for pre-record toolbar keyboard shortcuts:
//  Return starts video, Option+Return starts a GIF, other combinations do nothing.
//

import AppKit
@testable import Snapzy
import XCTest

final class RecordingPreRecordKeyTests: XCTestCase {
  func testReturnAndKeypadEnterStartVideo() {
    XCTAssertEqual(RecordingPreRecordKey.startAction(keyCode: 36, modifierFlags: []), .video)
    XCTAssertEqual(RecordingPreRecordKey.startAction(keyCode: 76, modifierFlags: []), .video)
  }

  func testOptionReturnStartsGIF() {
    XCTAssertEqual(RecordingPreRecordKey.startAction(keyCode: 36, modifierFlags: .option), .gif)
  }

  func testShiftReturnStartsStudio() {
    XCTAssertEqual(RecordingPreRecordKey.startAction(keyCode: 36, modifierFlags: .shift), .studio)
  }

  func testOtherModifierCombinationsAreIgnored() {
    for flags: NSEvent.ModifierFlags in [.command, .control, [.option, .shift]] {
      XCTAssertNil(RecordingPreRecordKey.startAction(keyCode: 36, modifierFlags: flags))
    }
  }

  func testOtherKeysAreIgnored() {
    for code: UInt16 in [53, 49, 1] { // Escape, Space, S
      XCTAssertNil(RecordingPreRecordKey.startAction(keyCode: code, modifierFlags: []))
    }
  }
}
