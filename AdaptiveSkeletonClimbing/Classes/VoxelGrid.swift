//
//  AdaptiveSkeletonClimber.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 08/07/2020.
//

import Euclid

public class VoxelGrid {

    static let G_Threshold = 50.0
    
    public var data : [Int]
    public let width : Int
    public let height : Int
    public let depth : Int
    
    public init(width : Int, height : Int, depth : Int) {
        self.width = width
        self.height = height
        self.depth = depth
        self.data = [Int](repeating: 0, count: width * height * depth)
    }
    
    public func generateMesh() -> Mesh {
        return Mesh([])
    }
}
