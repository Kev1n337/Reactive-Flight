//
//  ViewController.swift
//  Reactive Flight
//
//  Created by Kevin Linne on 26.11.17.
//  Copyright © 2017 Kevin Linne. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import MapKit
import CoreLocation
import Result
import UserNotifications

class ViewController: UIViewController {
    @IBOutlet weak var mapView: MapViewController!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var spriteKitView: SpriteKitViewController!
	@IBOutlet weak var enableSwitch: UISwitch!
	
	private let viewModel = {
		return ViewModel()
	}()
}

/*
	UIKit Overrides
*/
extension ViewController {
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.view.layoutSubviews()
		spriteKitView.setup(mapView: mapView, viewModel: viewModel)
		mapView.setup(viewModel: viewModel)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		_ = Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: { timer in
			self.viewModel.trigger(event: .ResetDestination)
		})
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.viewModel.enabled <~ enableSwitch.reactive.isOnValues
		
		self.viewModel.status.signal.observeValues {
			status in
			print("Status: \(status)")
			self.statusLabel.text = status
		}
		
		self.viewModel.events
			.filterMap { (event: ViewModelEvent) -> String? in
				switch event {
				case .Crash(let other):
					return other
				default:
				return nil
				}
			}
			.observeValues {
				let alert = UIAlertController(title: "Crash", message: "\($0)", preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "OK", style: .default))
				self.present(alert, animated: true, completion: nil)
			}
		
		self.statusLabel.reactive.text <~ self.viewModel.dataCounter.signal
			.throttle(0.1, on: QueueScheduler.main)
			.map { dataCount -> String in
				let displayablePlanes = self.viewModel.planes.filter {
					guard
						let _ = DisplayablePlane.fromPartialPlane(partialPlane: $0.value) else {
							return false
					}
					return true
				}
				return "\(displayablePlanes.count)/\(self.viewModel.planes.count)/\(dataCount)"
			}
		
		self.viewModel.destination.signal
			.filterMap { return $0 }
			.observeValues {
				let alert = UIAlertController(title: "New Destination", message: $0.name, preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "OK", style: .default))
				self.present(alert, animated: true, completion: nil)
			}
		
		self.viewModel.status.value = "Waiting for data..."
	}
}
