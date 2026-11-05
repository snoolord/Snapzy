//
//  VideoEditorAutoZoomPlanner.swift
//  Snapzy
//
//  Picks where to place auto-zoom segments: each recorded click zooms in on the cursor,
//  and clicks close together share one segment.
//

import Foundation

nonisolated enum VideoEditorAutoZoomPlanner {
  struct Plan: Equatable {
    var startTime: TimeInterval
    var duration: TimeInterval
  }

  /// Zoom starts this long before the click so the camera is already in place.
  static let leadIn: TimeInterval = 0.5
  /// Zoom holds this long after the last click it covers.
  static let holdAfter: TimeInterval = 1.5
  static let maxDuration: TimeInterval = ZoomSegment.maxDuration

  static func plan(clickTimes: [TimeInterval], videoDuration: TimeInterval) -> [Plan] {
    var plans: [Plan] = []
    for click in clickTimes.sorted() {
      let end = min(click + holdAfter, videoDuration)
      if var last = plans.last, click - leadIn <= last.startTime + last.duration,
         end - last.startTime <= maxDuration {
        last.duration = end - last.startTime
        plans[plans.count - 1] = last
        continue
      }
      let start = max(click - leadIn, plans.last.map { $0.startTime + $0.duration } ?? 0)
      if end - start >= ZoomSegment.minDuration {
        plans.append(Plan(startTime: start, duration: end - start))
      }
    }
    return plans
  }
}
