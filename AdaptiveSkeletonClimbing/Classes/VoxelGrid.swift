//
//  AdaptiveSkeletonClimber.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 08/07/2020.
//

import Euclid

enum VoxelAxis : Int {
    case none = 0
    case xy = 1
    case yz = 2
    case multiple = 3
}

public class VoxelGrid : Sequence {

    static let G_Threshold = 50.0
    
    public var data : [Int]
    public let width : Int
    public let height : Int
    public let depth : Int
    
    internal var boundingBoxes : [VoxelBoundingBox] = []
    
    public init(width : Int, height : Int, depth : Int) {
        self.width = width
        self.height = height
        self.depth = depth
        self.data = [Int](repeating: 0, count: width * height * depth)
    }
    
    public func generateMesh() -> Mesh {
        return Mesh([])
    }
    
    public func makeIterator() -> SlicesIterator {
        return SlicesIterator(grid: self)
    }
    
    internal func addBoundingBox(_ bounds: VoxelBoundingBox) {
        // See if this bounds intersects any intersecting bounds
//        for intersection in findIntersections(with: bounds) {
//            mergeIntersection(intersection)
//        }
        
        boundingBoxes.append(bounds)
    }
    
    private func mergeIntersection(_ intersection : VoxelBoundingBox) {
        // Partition the bounding boxes so that all of the overlapping ones are together
        let firstOverlappingIndex = boundingBoxes.partition(by: { $0.axis == .multiple })
        
        var hasMerged = false
        for i in firstOverlappingIndex ..< boundingBoxes.count {
            if (boundingBoxes[i].intersects(with: intersection)) {
                // Let's remove this element, merge and then re-insert the result
                boundingBoxes.swapAt(i, boundingBoxes.count - 1)
                var overlapping = boundingBoxes.popLast()!
                overlapping.merge(intersection)
                mergeIntersection(overlapping)
                hasMerged = true
                break
            }
        }
        
        if (!hasMerged) {
            boundingBoxes.append(intersection)
        }
    }
    
    private func findIntersections(with bounds : VoxelBoundingBox) -> [VoxelBoundingBox] {
        
        var intersections : [VoxelBoundingBox] = []
        for otherBounds in boundingBoxes {
            guard otherBounds.axis != .multiple else { continue }
            
            if let intersection = bounds.intersection(with: otherBounds) {
                // See if this intersects any existing intersections
                intersections.append(intersection)
            }
        }
        return intersections
    }
}
