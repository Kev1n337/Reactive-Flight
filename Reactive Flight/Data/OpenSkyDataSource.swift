//
//  OpenSkyDataSource.swift
//  Reactive Flight
//
//  Created by Samuel Schepp on 25.02.18.
//  Copyright © 2018 Kevin Linne. All rights reserved.
//

import Foundation
import ReactiveSwift
import ReactiveCocoa

class OpenSkyDataSource: DataSource {
	
	typealias A = OpenSkyDataObject
	typealias B = OpenSkyError
	
	private var timer = Timer()
	private var signal: Signal<OpenSkyDataObject, OpenSkyError>?
	private var observer: Signal<OpenSkyDataObject, OpenSkyError>.Observer?
	
	static var instance = {
		return OpenSkyDataSource()
	}()
	
	func start() -> Signal<OpenSkyDataObject, OpenSkyError> {
		if signal == nil {
			let pipe = Signal<OpenSkyDataObject, OpenSkyError>.pipe()
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
			let request = URLRequest(url: URL(string: "https://opensky-network.org/api/states/all")!)
			URLSession.shared.reactive.data(with: request).start { result in
				guard let observer = self.observer else {
					return;
				}
				
				guard let data = result.value?.0 else {
					observer.send(value: .JsonParseError(raw: result.value as Any))
					return;
				}
				
				var possibleJsonObject: (Any)? = nil
				do {
					possibleJsonObject = try JSONSerialization.jsonObject(with: data)
				}
				catch { }
				
				guard let jsonObject = possibleJsonObject else {
					observer.send(error: OpenSkyError.JsonParse)
					return;
				}
				
				guard let object = jsonObject as? Dictionary<String, Any> else {
					observer.send(error: OpenSkyError.JsonParse)
					return;
				}
				guard let states = object["states"] as? Array<Array<Any>> else {
					observer.send(error: OpenSkyError.JsonParse)
					return;
				}
			
                let planes: [OpenSkyPlane] = states.map { state in
					guard let icao24 = state[0] as? String else {
						DispatchQueue.main.async {
							observer.send(value: .JsonParseError(raw: "Error reading icao24 = state[0] from \(state)"))
						}
						return nil;
					}
					
					guard let longitude = state[5] as? Double else {
						DispatchQueue.main.async {
							observer.send(value: .JsonParseError(raw: "Error reading longitude = state[5] from \(state)"))
						}
						return nil;
					}
					
					guard let latitude = state[6] as? Double else {
						DispatchQueue.main.async {
							observer.send(value: .JsonParseError(raw: "Error reading latitude = state[6] from \(state)"))
						}
						return nil;
					}
					
					guard let heading = state[10] as? Double else {
						DispatchQueue.main.async {
							observer.send(value: .JsonParseError(raw: "Error reading heading = state[10] from \(state)"))
						}
						return nil;
					}
                    
                    return OpenSkyPlane(
                        icao24:     icao24.uppercased(),
                        longitude:     longitude,
                        latitude:     latitude,
                        heading:     heading
                    )
				}
				.filter {
					return $0 != nil
				}
				.map {
					return $0!
				}
				
				print("Open Sky: \(planes.count)")
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

enum OpenSkyError: Error {
	case Unknown(message: String)
	case JsonParse
	case Endpoint
}

enum OpenSkyDataObject {
	case Planes(planes: [OpenSkyPlane])
	case JsonParseError(raw: Any)
}

struct OpenSkyPlane {
	let icao24: String
	let longitude: Double
	let latitude: Double
	let heading: Double
	
	func getID() -> String {
		return icao24;
	}
}
