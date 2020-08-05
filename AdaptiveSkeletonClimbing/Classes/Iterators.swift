//
//  XYIterator.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 04/08/2020.
//

import Foundation

public struct XYIterator : IteratorProtocol, Sequence {
    
    private let grid : VoxelGrid
    private let xRange : Range<Int>
    private let yRange : Range<Int>
    private var x : Int
    private var y : Int
    private let z : Int
    private var index : Int
    
    init(grid: VoxelGrid, xRange : Range<Int>, yRange : Range<Int>, z : Int) {
        self.grid = grid
        self.xRange = xRange
        self.yRange = yRange
        
        x = xRange.lowerBound - 1
        y = yRange.lowerBound
        self.z = z
        index = xRange.lowerBound + yRange.lowerBound * grid.width + z * (grid.width * grid.height) - 1
    }
    
    public mutating func next() -> (Int, Int, Int, Int)? {
        x += 1
        index += 1
        if (x >= xRange.upperBound) {
            index += (grid.width - xRange.upperBound) + xRange.lowerBound
            x = xRange.lowerBound
            y += 1
            
            if (y >= yRange.upperBound) {
                return nil
            }
        }
        
        return (x, y, z, index)
    }
}

public struct ZIterator : IteratorProtocol, Sequence {

    private var x : Int
    private var y : Int
    private var z : Int
    private let zRange : Range<Int>
    private var index : Int
    private let layerOffset : Int

    init(grid: VoxelGrid, x : Int, y : Int, zRange : Range<Int>) {
        self.x = x
        self.y = y
        self.zRange = zRange
        
        layerOffset = (grid.width * grid.height)
        
        z = zRange.lowerBound - 1
        index = x + y * grid.width + z * layerOffset
    }

    public mutating func next() -> (Int, Int, Int, Int)? {
        z += 1
        index += layerOffset
        if (z >= zRange.upperBound) {
            return nil
        } else {
            return (x, y, z, index)
        }
    }

}
