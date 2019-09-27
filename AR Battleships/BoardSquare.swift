//
//  BoardSquare.swift
//  AR Battleships
//
//  Created by Sean Startin on 27/09/2019.
//  Copyright © 2019 Appoly Ltd. All rights reserved.
//

import Foundation
 
class BoardSquare {
    enum Status: Int {
        case fogged = 0
        case hiddenShip = 1
        case revealedNoShip = 2
        case revealedShip = 3
        case revealedDestroyedShip = 4
    }
    
    var ownerID: String
    var statusForOwner: Status
    var statusForOpponent: Status {
        switch statusForOwner {
        case .hiddenShip:
            return .fogged
        default:
            return statusForOwner
        }
    }
    var statusForSpectators: Status {
        return statusForOwner
    }
    
    init(ownerID: String, statusForOwner: Status) {
        self.ownerID = ownerID
        self.statusForOwner = statusForOwner
    }
    
    func statusFor(id: String) -> Status {
        if id == ownerID {
            return statusForOwner
        } else {
            return statusForOpponent
        }
    }
}
