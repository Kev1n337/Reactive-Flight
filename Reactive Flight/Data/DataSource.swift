//
//  DataSource.swift
//  Reactive Flight
//
//  Created by Samuel Schepp on 26.11.17.
//  Copyright © 2017 Kevin Linne. All rights reserved.
//

import Foundation
import ReactiveSwift

protocol DataSource {
	associatedtype A
	associatedtype B: Error
	func start() -> Signal<A, B>
	func stop()
}

