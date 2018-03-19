//
//  SpriteKitViewController.swift
//  Reactive Flight
//
//  Created by Samuel Schepp on 13.12.2017.
//  Copyright © 2017 Kevin Linne. All rights reserved.
//

import Foundation
import SpriteKit

class SpriteKitViewController: SKView {
	
	func setup(mapView: MapViewController, viewModel: ViewModel) {
		let scene = SceneController(size: self.bounds.size)
		self.presentScene(scene)
		
		scene.setup(mapView: mapView, viewModel: viewModel)
		
		self.allowsTransparency = true
		self.scene?.backgroundColor = .clear
		self.showsFPS = true
		self.showsNodeCount = true
	}
}

extension SpriteKitViewController {
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		let latest = convert((scene as! SceneController).playerNode.position, from: scene!)
		TouchDataSource.instance.touchesBegan(touches, with: event, in: self, latest: latest)
	}
	
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		TouchDataSource.instance.touchesMoved(touches, with: event, in: self)
	}
	
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		TouchDataSource.instance.touchesEnded(touches, with: event)
	}
}

extension CGPoint {
	func magnitude() -> CGFloat {
		return sqrt(pow((x), 2) + pow((y), 2))
	}
	
	func distanceTo(point: CGPoint) -> CGFloat {
		return sqrt(pow((point.x - x), 2) + pow((point.y - y), 2))
	}
	
	func delta(point: CGPoint) -> CGPoint {
		return CGPoint(x: x - point.x, y: y - point.y)
	}
	
	func add(point: CGPoint) -> CGPoint {
		return CGPoint(x: x + point.x, y: y + point.y)
	}
	
	func div(value: CGFloat) -> CGPoint {
		return CGPoint(x: x / value, y: y / value)
	}
	
	func mul(value: CGFloat) -> CGPoint {
		return CGPoint(x: x * value, y: y * value)
	}
	
	func normalized() -> CGPoint {
		let m = magnitude()
		if m > 0 {
			return div(value: m)
		}
		else {
			return self
		}
	}
}
