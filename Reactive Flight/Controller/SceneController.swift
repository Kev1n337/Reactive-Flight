//
//  SceneController.swift
//  Reactive Flight
//
//  Created by Samuel Schepp on 03.03.18.
//  Copyright © 2018 Kevin Linne. All rights reserved.
//

import Foundation
import SpriteKit
import CoreLocation
import GameplayKit
import ReactiveSwift
import Result

class SceneController: SKScene {
	private var nodeMap: [String: (SKNode, MapPlane)] = [:]
	private var touchNodesContainer = SKNode()
	public var playerNode: SKSpriteNode!
	private var pathNode: SKShapeNode?
	private var targetNode: SKShapeNode?
	private var mapView: MapViewController?
	private var viewModel: ViewModel!
	
	private let planeSpeed = CGFloat(40)
	private let destinationRadius = CGFloat(40)
	
	func setup(mapView: MapViewController, viewModel: ViewModel) {
		self.mapView = mapView
		self.viewModel = viewModel
		
		playerNode = SKSpriteNode(imageNamed: "plane.png")
		playerNode.setScale(0.2)
		playerNode.physicsBody = SKPhysicsBody(texture: playerNode.texture!, alphaThreshold: 0.9, size: playerNode.size)
		playerNode.physicsBody!.collisionBitMask = 1
		playerNode.physicsBody!.isDynamic = true
		playerNode.zPosition = 99
		resetPlayer()
		
		physicsWorld.gravity = CGVector.zero
		addChild(touchNodesContainer)
		addChild(playerNode)
		
		viewModel.events.observeValues {
			event in
			switch event {
			case .Crash(_):
				self.clearPath()
				self.resetPlayer()
			case .TouchStarted:
				self.touchesStarted()
			case .TouchAdded(let touch):
				self.addTouchOverlay(location: touch)
			case .TouchDone:
				self.touchesDone()
			default:
				()
			}
		}
		
		let planeStream: Signal<MapPlane, NoError> = viewModel.displayablePlanes
			.map { plane in
				let viewPoint = self.mapView!.convert(CLLocationCoordinate2D(latitude: plane.latitude, longitude: plane.longitude), toPointTo: self.view!)
				let point = self.view!.convert(viewPoint, to: self)
				let headingRad = -CGFloat(Measurement(value: plane.heading, unit: UnitAngle.degrees).converted(to: .radians).value)
				
				return MapPlane(icao24: plane.icao24, modelName: plane.modelName, point: point, heading: headingRad, from: plane.from, to: plane.to)
			}
			.filter { (plane: MapPlane) -> Bool in
				return self.view!.bounds.contains(plane.point)
			}
		
		let newPlanes = planeStream.filter {
			return !self.nodeMap.keys.contains($0.getID())
		}
		
		let existingPlanes = planeStream.filter {
			return self.nodeMap.keys.contains($0.getID())
		}
		
		newPlanes.observeValues {
			let node = SKSpriteNode(imageNamed: "plane.png")
			node.setScale(0.1)
			node.name = $0.getID()
			node.zRotation = $0.heading
			node.physicsBody = SKPhysicsBody(texture: node.texture!, alphaThreshold: 0.9, size: node.size)
			node.physicsBody!.isDynamic = false
			node.physicsBody!.collisionBitMask = 1
			node.position = $0.point;
			
			self.addChild(node)
			self.nodeMap[$0.getID()] = (node, $0)
		}
		
		existingPlanes.observeValues {
			let (node, plane) = self.nodeMap[$0.getID()]!
			node.name = plane.getID()
			node.removeAllActions()
			node.run(SKAction.move(to: $0.point, duration: 12)) // eig 10
			node.run(SKAction.rotate(toAngle: $0.heading, duration: 12, shortestUnitArc: true))
			self.nodeMap[plane.getID()] = (node, plane)
		}
		
		viewModel.destination.signal.observeValues {
			guard let destination = $0 else {
				return
			}
			
			if self.targetNode == nil {
				self.targetNode = SKShapeNode(circleOfRadius: self.destinationRadius)
				self.targetNode!.strokeColor = .green
				self.targetNode!.fillColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.2)
				self.addChild(self.targetNode!)
			}
			let viewPoint = self.mapView!.convert(destination.position, toPointTo: self.view)
			self.targetNode!.position = self.view!.convert(viewPoint, to: self)
		}
	}
	
	func resetPlayer() {
		playerNode.removeAllActions()
		playerNode.position = self.view!.convert(CGPoint(x: CGFloat(GKRandomSource.sharedRandom().nextInt(upperBound: Int((self.view?.bounds.width)!))), y: CGFloat(GKRandomSource.sharedRandom().nextInt(upperBound: 0) + 200)), to: self)
		playerNode.zRotation = CGFloat(GKRandomSource.sharedRandom().nextUniform() * 2 * .pi)
	}
	
	func addTouchOverlay(location: TouchData) {
		let node = SKShapeNode(circleOfRadius: 5)
		node.fillColor = .red
		node.strokeColor = UIColor(white: 1, alpha: 1)
		let loc = self.view!.convert(location.location, to: self) 
		node.position = loc
		touchNodesContainer.addChild(node)
	}
	
	func touchesDone() {
		guard let path = PathLib.getPathFrom(nodes: touchNodesContainer.children) else {
			return;
		}
		
		pathNode = SKShapeNode(path: path)
		pathNode!.strokeColor = .red
		self.scene?.addChild(pathNode!)
		
		let action = SKAction.follow(path, asOffset: false, orientToPath: true, speed: planeSpeed)
		
		playerNode.run(action, completion: {
			self.clearPath()
			self.checkDestination()
		})
	}
	
	private func checkDestination() {
		if let destination = viewModel.destination.value {
			let playerPos = playerNode.position
			let destinationPos = self.view!.convert(self.mapView!.convert(destination.position, toPointTo: self.view!), to: self)
			
			if playerPos.distanceTo(point: destinationPos) < destinationRadius {
				viewModel.trigger(event: .ResetDestination)
			}
		}
	}
	
	private func clearPath() {
		touchNodesContainer.removeAllChildren()
		pathNode?.removeFromParent()
	}
	
	func touchesStarted() {
		playerNode.removeAllActions()
		clearPath()
	}
	
	override func update(_ currentTime: TimeInterval) {
		super.update(currentTime)
		
		if playerNode.physicsBody!.allContactedBodies().count > 0  {
			guard
				let otherID = playerNode.physicsBody?.allContactedBodies().first?.node?.name,
				let otherPlane = nodeMap[otherID]?.1 else {
					return
			}
			viewModel.trigger(event: .Crash(other: "You crashed into \(otherPlane.modelName).\n\n\(otherPlane.from) -> \(otherPlane.to)"))
		}
	}
}

struct MapPlane {
	let icao24: String
	let modelName: String
	let point: CGPoint
	let heading: CGFloat
	let from: String
	let to: String
	
	func getID() -> String {
		return icao24;
	}
}
