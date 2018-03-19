//
//  ADSBExchange.swift
//  Reactive Flight
//
//  Created by Samuel Schepp on 17.03.18.
//  Copyright © 2018 Kevin Linne. All rights reserved.
//

import Foundation
import ReactiveSwift
import ReactiveCocoa

class ADSBExchange: DataSource {
	
	typealias A = ADSBExchangeDataObject
	typealias B = ADSBExchangeError
	
	private var timer = Timer()
	private var signal: Signal<A, B>?
	private var observer: Signal<A, B>.Observer?
	
	static var instance = {
		return ADSBExchange()
	}()
	
	func start() -> Signal<A, B> {
		if signal == nil {
			let pipe = Signal<A, B>.pipe()
			signal = pipe.output
			observer = pipe.input
			
			self.run(wait: false)
			self.timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: {
				timer in
				self.run(wait: true)
			})
		}
		
		return signal!
	}
	
	func stop() {
		timer.invalidate()
	}
	
	private func run(wait: Bool) {
		DispatchQueue.global(qos: .background).async {
			let request = URLRequest(url: URL(string: "https://public-api.adsbexchange.com/VirtualRadar/AircraftList.json")!)
			URLSession.shared.reactive.data(with: request).start { result in
				guard let observer = self.observer else {
					return;
				}
				
				guard let data = result.value?.0 else {
					DispatchQueue.main.async {
						observer.send(value: .JsonParseError(raw: result.value as Any))
					}
					return;
				}
				
				var possibleJsonObject: (Any)? = nil
				do {
					possibleJsonObject = try JSONSerialization.jsonObject(with: data)
				}
				catch { }
				
				guard
					let jsonObject = possibleJsonObject,
					let object = jsonObject as? Dictionary<String, Any>,
					let acList = object["acList"] as? Array<Dictionary<String, Any>> else {
					DispatchQueue.main.async {
						observer.send(error: .JsonParse)
					}
					return;
				}
				let planes: [ADSBExchangePlane] = acList.map { state in
					guard
						let icao24 = state["Icao"] as? String,
						let modelName = state["Mdl"] as? String,
						let to = state["To"] as? String,
						let from = state["From"] as? String else {
						return nil;
					}
					
					return ADSBExchangePlane(
						icao24:     icao24,
						modelName:  modelName,
						to: 		to,
						from: 		from
					)
					}
					.filter {
						return $0 != nil
					}
					.map {
						return $0!
				}
				
				print("ADSBE: \(planes.count)")
				let chunkedPlane = planes.chunked(by: 100)
				
				chunkedPlane.forEach {
					planes in
					DispatchQueue.main.async {
						observer.send(value: .Planes(planes: planes))
					}
					Thread.sleep(forTimeInterval: 1.0 / 60.0)
				}
			}
		}
	}
}

enum ADSBExchangeError: Error {
	case Unknown(message: String)
	case JsonParse
	case Endpoint
}

enum ADSBExchangeDataObject {
	case Planes(planes: [ADSBExchangePlane])
	case JsonParseError(raw: Any)
}

struct ADSBExchangePlane {
	let icao24: String
	let modelName: String
	let to: String
	let from: String
	
	func getID() -> String {
		return icao24;
	}
}
