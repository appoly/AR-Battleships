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
import MultipeerConnectivity

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var setupGameButton: UIButton!
    @IBOutlet weak var infoLabel: UILabel!
    
    @IBAction func setupGameButton_TouchUpInside(_ sender: Any) {
        if status == .broadcastingGame {
            stopbroadcastingGame()
        } else {
            generateAnchors()
            broadcastGame()
        }
    }
    
    enum Status {
        case searchingForNearby
        case broadcastingGame
        case inGame
    }
    
    var nodes = [String : SCNNode]()
    var anchors = [String: BoardSquareAnchor]()
    var myID = MCPeerID(displayName: UIDevice.current.name) //Atm this obviously isn't 'secure' against screwing the game  up
    var opponentID: MCPeerID?
    var isMapProvider: Bool = false
    
    let boxSize: Float = 0.25
    
    var multiplayerSession: MCSession?
    var multiplayerServiceAdvertiser: MCNearbyServiceAdvertiser?
    var multiplayerServiceBrowser: MCNearbyServiceBrowser?
    
    let serviceType = "ar-battleships"

    var status: Status = .searchingForNearby {
        didSet {
            OperationQueue.main.addOperation {
                switch self.status {
                case .inGame:
                    self.infoLabel.isHidden = true
                    self.setupGameButton.isHidden = true
                case .broadcastingGame:
                    self.isMapProvider = true
                    self.infoLabel.isHidden = false
                    self.infoLabel.text = "Awaiting other players"
                    self.setupGameButton.isHidden = false
                    self.setupGameButton.setTitle("Cancel Setup", for: .normal)
                default:
                    self.isMapProvider = false
                    self.opponentID = nil
                    self.infoLabel.isHidden = false
                    self.infoLabel.text = "Joining nearby games..."
                    self.setupGameButton.isHidden = false
                    self.setupGameButton.setTitle("Setup Game", for: .normal)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        reset()
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
    
    func setupMultiplayer() {
        multiplayerSession = MCSession(peer: myID)
        multiplayerSession?.delegate = self
        
        multiplayerServiceBrowser = MCNearbyServiceBrowser(peer: myID, serviceType: serviceType)
        multiplayerServiceBrowser?.delegate = self
        multiplayerServiceBrowser?.startBrowsingForPeers()
    }
    
    func broadcastGame() {
        multiplayerServiceAdvertiser = MCNearbyServiceAdvertiser(peer: myID, discoveryInfo: nil, serviceType: serviceType)
        multiplayerServiceAdvertiser?.delegate = self
        multiplayerServiceAdvertiser?.startAdvertisingPeer()
        
        status = .broadcastingGame
    }
    
    func sendDataIfProvider() {
        if isMapProvider {
            sceneView.session.getCurrentWorldMap { worldMap, error in
                guard let map = worldMap else {
                    print("Error generating map: \(error?.localizedDescription)")
                    return
                }
                
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: false)
                    
                    self.sendDataToOpponent(data: data)
                } catch {
                    print("Error sending map: \(error)")
                }

            }
            self.sendAnchors()
        }
    }
    
    func sendAnchors() {
        for anchor in anchors {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: false)
                
                sendDataToOpponent(data: data)
            } catch {
                print("Couldn't archive bsanchor: \(error.localizedDescription)")
            }
            
        }
    }
    
    func sendDataToOpponent(data: Data) {
        guard let opponentID = opponentID,
            let multiplayerSession = multiplayerSession else {
                return
        }
        
        do {
            try multiplayerSession.send(data, toPeers: [opponentID], with: .reliable)
        } catch {
            print("Data sending error: \(error.localizedDescription)")
        }
    }

    func stopbroadcastingGame() {
        multiplayerServiceAdvertiser?.stopAdvertisingPeer()
        multiplayerServiceAdvertiser = nil
        
        reset()
    }
    
    func reset() {
        for anchor in anchors.values {
            sceneView.session.remove(anchor: anchor)
        }
        
        for node in nodes.values {
            node.removeFromParentNode()
        }
        
        anchors.removeAll()
        nodes.removeAll()
        
        status = .searchingForNearby
        multiplayerSession?.disconnect()
        multiplayerServiceBrowser?.stopBrowsingForPeers()
        setupMultiplayer()
    }
    
    func generateAnchors() {
        //Test func at this point
        let gridSize = 8
        
        for i in 0..<gridSize {
            for k in 0..<gridSize {
                let status: BoardSquare.Status
                
                if i == 6 {
                    status = .revealedNoShip
                } else if i == 4 {
                    status = .revealedDestroyedShip
                } else if i == 2 {
                    status = .revealedShip
                } else if i == 0 {
                    status = .hiddenShip
                } else {
                    status = .fogged
                }
                
                let boardSquare = BoardSquare(ownerID: myID.displayName, statusForOwner: status)
                let position = BoardSquareAnchor.Position(i, k)
                var transform = matrix_identity_float4x4
                
                let gap = boxSize * 0.2
                let xGap = Float(i) * gap
                let yGap = Float(k) * gap
                
                transform.columns.3.x = (Float(i) * boxSize) + xGap
                transform.columns.3.y = -1
                transform.columns.3.z = (Float(k) * boxSize) + yGap
                
                let anchor = BoardSquareAnchor(boardSquare: boardSquare, position: position, transform: transform)
                
                anchors[anchor.name!] = anchor
                sceneView.session.add(anchor: anchor)
            }
        }
    }
    
    func addChildNode(forBoardSquareAnchor boardSquareAnchor: BoardSquareAnchor, withParentNode parentNode: SCNNode) {
        guard let nodeName = boardSquareAnchor.name else {
            print("Screwup")
            return
        }
        
        if let existingNode = nodes[nodeName] {
            existingNode.removeFromParentNode() //Remove existing node from scene, it may have changed
        }
        
        let box = createSCNBox(withBoardSquare: boardSquareAnchor.boardSquare, forID: myID.displayName)
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

extension ViewController: ARSCNViewDelegate {
    // MARK: - ARSCNViewDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {}
    func sessionWasInterrupted(_ session: ARSession) {}
    func sessionInterruptionEnded(_ session: ARSession) {}
        
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let boardSquareAnchor = anchor as? BoardSquareAnchor else { return }
            
        addChildNode(forBoardSquareAnchor: boardSquareAnchor, withParentNode: node)
    }
}

extension ViewController: MCSessionDelegate {
    // MARK: - MCSessionDelegate
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                //re run session with new world map from other person
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                configuration.initialWorldMap = worldMap
                sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            } else  if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: BoardSquareAnchor.self, from: data) {
                sceneView.session.add(anchor: anchor)
            } else {
                print("Data was fucked")
            }
        } catch {
            print("Data was fucked with error: \(error.localizedDescription)")
        }
        
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if peerID != myID {
            switch state {
            case .connected:
                status = .inGame
                sendDataIfProvider()
            case .notConnected:
                status = .searchingForNearby
            default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension ViewController: MCNearbyServiceAdvertiserDelegate {
    // MARK: - MCNearbyServiceAdvertiserDelegate

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        guard opponentID == nil else {
            invitationHandler(false, multiplayerSession)
            return
        }
        
        invitationHandler(true, multiplayerSession) //Accept any invitation automatically if no opponent
        status = .inGame
    }
}

extension ViewController: MCNearbyServiceBrowserDelegate {
    // MARK: - MCNearbyServiceBrowserDelegate

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard opponentID == nil, let multiplayerSession = multiplayerSession else { return }
    
        browser.invitePeer(peerID, to: multiplayerSession, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        status = .searchingForNearby
    }
}
