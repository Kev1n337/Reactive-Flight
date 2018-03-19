//
//  TouchDataSource.swift
//  Reactive Flight
//
//  Created by Samuel Schepp on 25.02.18.
//  Copyright © 2018 Kevin Linne. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import UIKit

class TouchDataSource: DataSource {
	typealias A = TouchDataObject
	typealias B = NoError
	
	private var signal: Signal<TouchDataObject, NoError>?
	private var observer: Signal<TouchDataObject, NoError>.Observer?
	private var latestTouch: TouchData?
	
	static var instance = {
		return TouchDataSource()
	}()
	
	func start() -> Signal<A, B> {
		if signal == nil {
			let pipe = Signal<TouchDataObject, NoError>.pipe()
			signal = pipe.output
			observer = pipe.input
		}
		
		return signal!
	}
	
	func stop() {
		
	}
	
	func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView, latest: CGPoint) {
		guard
			let observer = self.observer
			else {
				return;
		}
		
		latestTouch = TouchData(location: latest)
		observer.send(value: TouchDataObject.TouchStarted)
		observer.send(value: TouchDataObject.TouchAdded(touch: TouchData(location: latest)))
		touchesMoved(touches, with: event, in: view)
	}
	
	func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
		guard
			let touch = touches.first,
			let observer = self.observer
			else {
				return;
		}
		
		let currentPoint = TouchData(location: touch.location(in: view))
		while currentPoint.location.distanceTo(point: latestTouch!.location) > 20 {
			// Hier muss ein Unwrapping stattfinden, damit der neuste Wert geprüft werden kann.
			let delta = currentPoint.location.delta(point: latestTouch!.location)
			let target = TouchData(location: 
				latestTouch!.location.add(point: delta.normalized().mul(value: 20))
			)
			observer.send(value: .TouchAdded(touch: target))
			self.latestTouch = target;
		}
	}
	
	func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard
			let observer = self.observer
			else {
				return;
		}
		observer.send(value: .TouchDone)
	}
}

enum TouchDataObject {
	case TouchStarted
	case TouchAdded(touch: TouchData)
	case TouchDone
}

struct TouchData {
	let location: CGPoint
}
