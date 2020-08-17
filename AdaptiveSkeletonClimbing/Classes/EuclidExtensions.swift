//
//  EuclidExtensions.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 17/08/2020.
//

import Foundation
import Euclid

let epsilon = 1e-6

extension Vector {
    func isAbove(plane: Plane) -> Bool {
        return distance(from: plane) > epsilon
    }
    
    func isBelow(plane: Plane) -> Bool {
        return distance(from: plane) < -epsilon
    }
}
