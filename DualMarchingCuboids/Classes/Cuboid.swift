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
//    let x : Int
//    let y : Int
//    let z : Int
    let index : Int // Can derive x, y, z from this
    
    let width : Int
    let height : Int
    let depth : Int
    
    let marchingCubesCase : Int
    
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
    
    func position(grid: VoxelGrid) -> (Int, Int, Int) {
        let z = index / (grid.width * grid.height)
        let y = (index - z * (grid.width * grid.height)) / grid.width
        let x = index % (grid.width * grid.height)
        return (x, y, z)
    }
    
    public func mesh(grid: VoxelGrid) -> Mesh {
        let (x, y, z) = position(grid: grid)
        let corner = Vector(Double(x), Double(y), Double(z))
        let cellSize = Vector(Double(width), Double(height), Double(depth))
        let centre = corner + cellSize * 0.5
        let cuboid = Mesh.cube(center: Vector.zero, size: 1.0, faces: .front, material: randomColor()).scaled(by: cellSize).translated(by: centre)
        return cuboid
    }
}
