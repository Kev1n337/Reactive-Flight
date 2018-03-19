//
//  PathLib.swift
//  Reactive Flight
//
//  Created by Samuel Schepp on 04.03.18.
//  Copyright © 2018 Kevin Linne. All rights reserved.
//

import Foundation
import SpriteKit

class PathLib {
	class func getPathFrom(nodes: [SKNode]) -> CGPath? {
		return newPathFrom(points: nodes.map {
			return $0.position
		})
	}
	
	class func newPathFrom(points: [CGPoint]) -> CGPath {
		let bezierPath = UIBezierPath()
		var prevPoint: CGPoint?
		var isFirst = true
		
		for point in points {
			if let prevPoint = prevPoint {
				let midPoint = CGPoint(
					x: (point.x + prevPoint.x) / 2,
					y: (point.y + prevPoint.y) / 2)
				if isFirst {
					bezierPath.addLine(to: midPoint)
				}
				else {
					bezierPath.addQuadCurve(to: midPoint, controlPoint: prevPoint)
				}
				isFirst = false
			}
			else { 
				bezierPath.move(to: point)
			}
			prevPoint = point
		}
		if let prevPoint = prevPoint {
			bezierPath.addLine(to: prevPoint)
		}
		
		return bezierPath.cgPath
	}
}

extension Array {
	func chunked(by chunkSize: Int) -> [[Element]] {
		return stride(from: 0, to: self.count, by: chunkSize).map {
			Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
		}
	}
}
