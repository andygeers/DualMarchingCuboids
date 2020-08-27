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
    
    mutating func merge(_ bounds : VoxelBoundingBox) {
        merge(bounds.min)
        merge(bounds.max)
    }
    
    var firstIndex : Int {
        switch (axis) {
        case .xy:
            return min.z
        case .yz:
            return min.x
        case .multiple:
            return min.z
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
        case .multiple:
            return max.z
        default:
            return Int.max
        }
    }
    
    func intersects(with bounds : VoxelBoundingBox) -> Bool {
        return (self.min.x <= bounds.max.x) && (self.min.y <= bounds.max.y) && (self.min.z <= bounds.max.z) &&
            (self.max.x >= bounds.min.x) && (self.max.y >= bounds.min.y) && (self.max.z >= bounds.min.z)
    }
    
    func intersection(with bounds : VoxelBoundingBox) -> VoxelBoundingBox? {
        guard self.intersects(with: bounds) else { return nil }
        
        let intersectionMin = VoxelCoordinates(x: Swift.max(self.min.x, bounds.min.x), y: Swift.max(self.min.y, bounds.min.y), z: Swift.max(self.min.z, bounds.min.z))
        let intersectionMax = VoxelCoordinates(x: Swift.min(self.max.x, bounds.max.x), y: Swift.min(self.max.y, bounds.max.y), z: Swift.min(self.max.z, bounds.max.z))
        
        return VoxelBoundingBox(min: intersectionMin, max: intersectionMax, axis: .multiple)
    }
}
