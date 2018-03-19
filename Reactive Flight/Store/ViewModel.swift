//
//  ViewModel.swift
//  Reactive Flight
//
//  Created by Samuel Schepp on 13.12.17.
//  Copyright © 2017 Kevin Linne. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

/*
View Model
*/
class ViewModel {
	let dataCounter:		MutableProperty<Int>
	var planes:				[String: PartialPlane]
	
	let enabled:			MutableProperty<Bool>
	let status:				MutableProperty<String>
	let events:             Signal<ViewModelEvent, NoError>
	let destination:		MutableProperty<Destination?>
	let displayablePlanes:	Signal<DisplayablePlane, NoError>
	
	let eventsPipe:			Signal<ViewModelEvent, NoError>.Observer
	
	init() {
		dataCounter			= MutableProperty(0)
		planes 				= [String: PartialPlane]()
		enabled 			= MutableProperty(true)
		status				= MutableProperty("Unknown")
		(events, eventsPipe) = Signal.pipe()
		destination			= MutableProperty(nil)
		
		displayablePlanes = events
			.filterMap {
				switch $0 {
				case .PlaneUpdate(let plane):
					return plane
				default:
					return nil
				}
			}
			.filterMap { (plane: PartialPlane) -> DisplayablePlane? in
				guard
					let plane = DisplayablePlane.fromPartialPlane(partialPlane: plane)
					else {
						return nil
				}
				return plane
		}
		
		_ = OpenSkyDataSource.instance
			.start()
			.filter { _ in 
				return self.enabled.value
			}
			.filterMap { (value: OpenSkyDataObject) -> [OpenSkyPlane]? in
				switch value {
				case .Planes(let planes):
					return planes
				case .JsonParseError(_):
					return .none
				}
			}
			.flatten()
			.observe { (event) in
				switch event {
				case .value(let value):
					let plane = self.planes[value.getID()] ?? PartialPlane(icao24: value.icao24)
					plane.heading = value.heading
					plane.longitude = value.longitude
					plane.latitude = value.latitude
					self.planes[plane.getID()] = plane
					self.trigger(event: .PlaneUpdate(plane: plane))
					break
				case .failed(let error):
					print(error)
					break
				default:
					()
				}
			}
		
		_ = ADSBExchange.instance
			.start()
			.filter { _ in
				return self.enabled.value
			}
			.filterMap { (value: ADSBExchangeDataObject) -> [ADSBExchangePlane]? in
				switch value {
				case .Planes(let planes):
					return planes
				case .JsonParseError(_):
					return .none
				}
			}
			.flatten()
			.observe({ (event) in
				switch event {
				case .value(let value):
					let plane = self.planes[value.getID()] ?? PartialPlane(icao24: value.icao24)
					plane.modelName = value.modelName
					plane.to = value.to
					plane.from = value.from
					self.planes[plane.getID()] = plane
					self.trigger(event: .PlaneUpdate(plane: plane))
					break
				case .failed(let error):
					print(error)
					break
				default:
					()
				}
			})
		
		_ = TouchDataSource.instance
			.start()
			.map {
				switch $0 {
				case .TouchStarted:
					return ViewModelEvent.TouchStarted
				case .TouchAdded(let touch):
					return ViewModelEvent.TouchAdded(touch: touch)
				case .TouchDone:
					return ViewModelEvent.TouchDone
				}
			}
			.observeValues {
				self.eventsPipe.send(value: $0)
			}
	}
	
	func trigger(event: ViewModelEvent) {
		switch event {
		case .PlaneUpdate(_):
			dataCounter.value = dataCounter.value + 1
		default:
			()
		}
		
		eventsPipe.send(value: event)
	}
}

enum ViewModelEvent {
	case PlaneUpdate(plane: PartialPlane)
	case ResetDestination
	case Crash(other: String)
	case TouchStarted
	case TouchAdded(touch: TouchData)
	case TouchDone
}

struct DisplayablePlane {
	let icao24: String
	let modelName: String
	let longitude: Double
	let latitude: Double
	let heading: Double
	let to: String
	let from: String
	
	static func fromPartialPlane(partialPlane: PartialPlane) -> DisplayablePlane? {
		guard
			let latitude = partialPlane.latitude,
			let longitude = partialPlane.longitude,
			let heading = partialPlane.heading,
			let modelName = partialPlane.modelName,
			let to = partialPlane.to,
			let from = partialPlane.from
			else {
				return nil
		}
		return DisplayablePlane(
			icao24: partialPlane.icao24, 
			modelName: modelName, 
			longitude: longitude, 
			latitude: latitude, 
			heading: heading, 
			to: to, 
			from: from)
	} 
	
	func getID() -> String {
		return icao24;
	}
}

class PartialPlane {
	let icao24: String
	var modelName: String?
	var longitude: Double?
	var latitude: Double?
	var heading: Double?
	var to: String?
	var from: String?
	
	init(icao24: String) {
		self.icao24 = icao24
	}
	
	func getID() -> String {
		return icao24;
	}
}
