//
//  VoxelBounds.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 08/08/2020.
//

import Foundation

struct VoxelCoordinates {
    let x : Int
    let y : Int
    let z : Int
    
    static let zero = VoxelCoordinates(x: 0, y: 0, z: 0)
    static let max = VoxelCoordinates(x: Int.max, y: Int.max, z: Int.max)
    
    var description : String {
        return String(format: "(%d, %d, %d)", x, y, z)
    }
}

struct VoxelBoundingBox {
    var min : VoxelCoordinates
    var max : VoxelCoordinates
    let axis : VoxelAxis
    
    mutating func merge(_ point: VoxelCoordinates, depth: Int = 0) {
        let offset : VoxelCoordinates
        switch (axis) {
        case .xy:
            offset = VoxelCoordinates(x: point.x, y: point.y, z: point.z + depth + 1)
            
        case .yz:
            offset = VoxelCoordinates(x: point.x + depth + 1, y: point.y, z: point.z)
            
        default:
            offset = point
        }
        
        min = VoxelCoordinates(x: Swift.min(point.x - 1, min.x, offset.x), y: Swift.min(point.y - 1, min.y, offset.y), z: Swift.min(point.z - 1, min.z, offset.z))
        max = VoxelCoordinates(x: Swift.max(point.x + 1, max.x, offset.x), y: Swift.max(point.y + 1, max.y, offset.y), z: Swift.max(point.z + 1, max.z, offset.z))
    }
    
    var firstIndex : Int {
        switch (axis) {
        case .xy:
            return min.z
        case .yz:
            return min.x
        default:
            return 0
        }
    }
    
    var finalIndex : Int {
        switch (axis) {
        case .xy:
            return max.z
        case .yz:
            return max.x
        default:
            return Int.max
        }
    }
}
