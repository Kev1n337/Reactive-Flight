//
//  MapViewController.swift
//  Reactive Flight
//
//  Created by Samuel Schepp on 25.02.18.
//  Copyright © 2018 Kevin Linne. All rights reserved.
//

import Foundation
import UIKit
import MapKit

class MapViewController: MKMapView {
	var counter = 0
	let pointAnnotation = MKPointAnnotation()
	
	let destinations: [Destination] = [
		Destination(name: "Gießen", position: CLLocationCoordinate2D(latitude: 50.586726, longitude: 8.676122)),
		Destination(name: "Korbach", position: CLLocationCoordinate2D(latitude: 51.272788, longitude: 8.849097)),
		Destination(name: "Limburg", position: CLLocationCoordinate2D(latitude: 50.397752, longitude: 8.088486)),
		Destination(name: "Stadtallendorf", position: CLLocationCoordinate2D(latitude: 50.829915, longitude: 9.020694)),
		Destination(name: "Herborn", position: CLLocationCoordinate2D(latitude: 50.676845, longitude: 8.278230)),
		Destination(name: "Budingen", position: CLLocationCoordinate2D(latitude: 50.286168, longitude: 9.073924)),
		Destination(name: "Frankfurt", position: CLLocationCoordinate2D(latitude: 50.114083, longitude: 8.629691))
	]
	
	func setup(viewModel: ViewModel) {
		setVisibleMapRect(MKMapRect(
			origin: MKMapPoint(x: 139983266.80345911, y: 89181564.800288349),
			size: MKMapSize(width: 1403675.9420210123, height: 2496671.6088746935)),animated: true)
		
		viewModel.events.observeValues {
			switch $0 {
			case .ResetDestination:
				viewModel.destination.value = self.destinations[self.counter]
				self.counter = (self.counter + 1) % self.destinations.count
			default:
				()
			}
		}
	}
}
