//
//  BoardSquareNode.swift
//  AR Battleships
//
//  Created by Sean Startin on 27/09/2019.
//  Copyright © 2019 Appoly Ltd. All rights reserved.
//

import Foundation
import SceneKit

class BoardSquareBox: SCNBox {
    private let boardSquare: BoardSquare
    
    init(withBoardSquare boardSquare: BoardSquare) {
        self.boardSquare = boardSquare
        
        
        super.init(width: 1, height: 1, length: 1, chamferRadius: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
