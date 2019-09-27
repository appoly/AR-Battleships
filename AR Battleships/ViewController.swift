//
//  ViewController.swift
//  AR Battleships
//
//  Created by Sean Startin on 27/09/2019.
//  Copyright © 2019 Appoly Ltd. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var nodes = [String : SCNNode]()
    var myID: String?
    let boxSize: Float = 0.25
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        generateAnchors()
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let boardSquareAnchor = anchor as? BoardSquareAnchor else { return }
        
        addChildNode(forBoardSquareAnchor: boardSquareAnchor, withParentNode: node)
    }
    
    
    func generateAnchors() {
        myID = "Sean"
        //Test func at this point
        let gridSize = 8
        
        for i in 0..<gridSize {
            for k in 0..<gridSize {
                let status: BoardSquare.Status
                
                if i == 7 {
                    status = .revealedNoShip
                } else if i == 5 {
                    status = .revealedDestroyedShip
                } else if i == 3 {
                    status = .revealedShip
                } else if i == 1 {
                    status = .hiddenShip
                } else {
                    status = .fogged
                }
                
                let boardSquare = BoardSquare(ownerID: myID!, statusForOwner: status)
                let position = BoardSquareAnchor.Position(i, k)
                var transform = matrix_identity_float4x4
                
                let gap = boxSize * 0.2
                let xGap = Float(i) * gap
                let yGap = Float(k) * gap
                
                transform.columns.3.x = (Float(i) * boxSize) + xGap
                transform.columns.3.y = -1
                transform.columns.3.z = (Float(k) * boxSize) + yGap
                
                let anchor = BoardSquareAnchor(boardSquare: boardSquare, position: position, transform: transform)
                sceneView.session.add(anchor: anchor)
            }
        }
    }
    
    func addChildNode(forBoardSquareAnchor boardSquareAnchor: BoardSquareAnchor, withParentNode parentNode: SCNNode) {
        guard let nodeName = boardSquareAnchor.name,
            let myID = myID else {
            print("Screwup")
            return
        }
        
        if let existingNode = nodes[nodeName] {
            existingNode.removeFromParentNode() //Remove existing node from scene, it may have changed
        }
        
        let box = createSCNBox(withBoardSquare: boardSquareAnchor.boardSquare, forID: myID)
        let boxNode = SCNNode()
        boxNode.geometry = box
        nodes[nodeName] = boxNode
        
        parentNode.addChildNode(boxNode)
    }
    
    func createSCNBox(withBoardSquare boardSquare: BoardSquare, forID id: String) -> SCNBox {
        let colour: UIColor
        let isShipPosition: Bool
        
        switch boardSquare.statusFor(id: id) {
        case .fogged:
            colour = UIColor.gray
            isShipPosition = false
        case .hiddenShip:
            colour = UIColor.green
            isShipPosition = true
        case .revealedNoShip:
            colour = UIColor.gray.withAlphaComponent(0.6)
            isShipPosition = false
        case .revealedShip:
            colour = UIColor.red
            isShipPosition = true
        case .revealedDestroyedShip:
            colour = UIColor.black
            isShipPosition = true
        }
        
        let boxSize = CGFloat(self.boxSize)
        let box = SCNBox(width: boxSize,
                         height: boxSize,
                         length: boxSize,
                         chamferRadius: isShipPosition ? 5 : 0)
        
        box.firstMaterial?.diffuse.contents = colour
        
        return box
    }
}
