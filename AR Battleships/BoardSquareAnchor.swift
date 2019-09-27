//
//  BoardSquare.swift
//  AR Battleships
//
//  Created by Sean Startin on 27/09/2019.
//  Copyright © 2019 Appoly Ltd. All rights reserved.
//

import Foundation
import ARKit

class BoardSquareAnchor: ARAnchor {
    private enum Keys {
        static let boardSquareOwnerIDKey = "BS_OWNER_ID"
        static let boardSquareStatusKey = "BS_STATUS_KEY"
        static let positionXKey = "BS_POSITION_X"
        static let positionYKey = "BS_POSITION_Y"
    }
    
    struct Position {
        let x: Int
        let y: Int
        
        init(_ x: Int, _ y: Int) {
            self.x = x
            self.y = y
        }
    }
    
    let boardSquare: BoardSquare
    let position: Position
    
    init(boardSquare: BoardSquare, position: Position, transform: simd_float4x4) {
        self.boardSquare = boardSquare
        self.position = position
        
        let name = BoardSquareAnchor.generateName(fromBoardSquare: boardSquare, position: position)
        
        super.init(name: name, transform: transform)
    }
    
    required init?(coder: NSCoder) {
        guard let ownerID = coder.decodeObject(forKey: Keys.boardSquareOwnerIDKey) as? String,
            let statusInt = coder.decodeObject(forKey: Keys.boardSquareStatusKey) as? Int,
            let positionX = coder.decodeObject(forKey: Keys.positionXKey) as? Int,
            let positionY = coder.decodeObject(forKey: Keys.positionYKey) as? Int,
            let status = BoardSquare.Status(rawValue: statusInt) else {
                fatalError("This shouldn't fucking happen sort it out")
        }
        
        boardSquare = BoardSquare(ownerID: ownerID, statusForOwner: status)
        position = Position(positionX, positionY)
        
        super.init(coder: coder)
    }
    
    required init(anchor: ARAnchor) {
        guard let boardSquareAnchor = anchor as? BoardSquareAnchor else {
            fatalError("fk")
        }
        
        boardSquare = boardSquareAnchor.boardSquare
        position = boardSquareAnchor.position
        
        super.init(anchor: anchor)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        
        coder.encode(boardSquare.ownerID, forKey: Keys.boardSquareOwnerIDKey)
        coder.encode(boardSquare.statusForOwner.rawValue, forKey: Keys.boardSquareStatusKey)
        coder.encode(position.x, forKey: Keys.positionXKey)
        coder.encode(position.y, forKey: Keys.positionYKey)
    }
    
    static func generateName(fromBoardSquare boardSquare: BoardSquare, position: Position) -> String {
        return "\(boardSquare.ownerID)[\(position.x),\(position.y)]"
    }
}
