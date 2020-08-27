//
//  Cuboid.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 27/08/2020.
//

import Foundation
import Euclid

fileprivate func randomColor() -> UIColor {
    return UIColor(red: CGFloat.random(in: 0 ... 1.0), green: CGFloat.random(in: 0 ... 1.0), blue: CGFloat.random(in: 0 ... 1.0), alpha: 0.5)
}

public struct Cuboid {
    var x : Int
    var y : Int
    var z : Int
    
    func index(grid: VoxelGrid) -> Int {
        return z * grid.width * grid.height + y * grid.width + x
    }
    
    var width : Int
    var height : Int
    var depth : Int
    
    var marchingCubesCase : Int = -1
    
    // There can be up to four discreet surfaces
    // in the most complex Marching Cubes case
    var vertex1 : Vector = Vector.zero
    var vertex2 : Vector = Vector.zero
    var vertex3 : Vector = Vector.zero
    var vertex4 : Vector = Vector.zero
    
    // There may of course be a lot of nodes along each edge, for large cuboids,
    // but we can find all of the others by traversing from the first one on that edge
    var upNodeIndex : Int = -1
    var rightNodeIndex : Int = -1
    var downNodeIndex : Int = -1
    var leftNodeIndex : Int = -1
    var forwardsNodeIndex : Int = -1
    var backwardsNodeIndex : Int = -1
    
    public func mesh(grid: VoxelGrid) -> Mesh {
        let corner = Vector(Double(x), Double(y), Double(z))
        let cellSize = Vector(Double(width), Double(height), Double(depth))
        let centre = corner + cellSize * 0.5
        let cuboid = Mesh.cube(center: Vector.zero, size: 1.0, faces: .front, material: randomColor()).scaled(by: cellSize).translated(by: centre)
        return cuboid
    }
    
    func sampleCorners(index: Int, grid: VoxelGrid) -> [Int] {
        
        let nextZ = grid.width * grid.height * depth
        let nextY = grid.width * height
        
        return [
            grid.data[index],
            z + depth < grid.depth ? grid.data[index + nextZ] : 0,
            x + width < grid.width && z + depth < grid.depth ? grid.data[index + nextZ + width] : 0,
            x + width < grid.width ? grid.data[index + width] : 0,
            y + height < grid.height ? grid.data[index + nextY] : 0,
            y + height < grid.height && z + depth < grid.depth ? grid.data[index + nextZ + nextY] : 0,
            x + width < grid.width && y + height < grid.height && z + depth < grid.depth ? grid.data[index + nextZ + width + nextY] : 0,
            x + width < grid.width && y + height < grid.height ? grid.data[index + width + nextY] : 0
        ]
    }
}
