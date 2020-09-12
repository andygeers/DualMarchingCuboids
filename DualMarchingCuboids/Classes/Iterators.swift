//
//  XYIterator.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 04/08/2020.
//

import Foundation

public class SliceAxisIterator : IteratorProtocol, Sequence {
    
    public func next() -> (Int, Int, Int, Int, Int, Int)? {
        return nil
    }
    
}

public class XYIterator : SliceAxisIterator {
    
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
        index = grid.cellIndex(x: x, y: y, z: z)
    }
    
    override public func next() -> (Int, Int, Int, Int, Int, Int)? {
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
        
        return (x, y, z, x, y, index)
    }
}

public class ZIterator : IteratorProtocol, Sequence {

    private var x : Int
    private var y : Int
    private var z : Int
    private let zRange : ClosedRange<Int>
    private var index : Int
    private let layerOffset : Int

    init(grid: VoxelGrid, x : Int, y : Int, zRange : ClosedRange<Int>) {
        self.x = x
        self.y = y
        self.zRange = zRange
        
        layerOffset = (grid.width * grid.height)
        
        z = zRange.lowerBound - 1
        index = x + y * grid.width + z * layerOffset
    }

    public func next() -> (Int, Int, Int, Int)? {
        z += 1
        index += layerOffset
        if (z > zRange.upperBound) {
            return nil
        } else {
            return (x, y, z, index)
        }
    }

}

public class YZIterator : SliceAxisIterator {
    
    private let grid : VoxelGrid
    private let yRange : Range<Int>
    private let zRange : Range<Int>
    private let x : Int
    private var y : Int
    private var z : Int
    private var index : Int
    
    init(grid: VoxelGrid, x : Int, yRange : Range<Int>, zRange : Range<Int>) {
        self.grid = grid
        self.yRange = yRange
        self.zRange = zRange
        
        self.x = x
        y = yRange.lowerBound
        z = zRange.lowerBound - 1
        
        index = grid.cellIndex(x: x, y: y, z: z)
    }
    
    override public func next() -> (Int, Int, Int, Int, Int, Int)? {
        z += 1
        index += grid.width * grid.height
        if (z >= zRange.upperBound) {
            z = zRange.lowerBound
            y += 1
            
            if (y >= yRange.upperBound) {
                return nil
            }
            
            index = grid.cellIndex(x: x, y: y, z: z)
        }
        
        return (x, y, z, z, y, index)
    }
}

public class XIterator : IteratorProtocol, Sequence {

    private var x : Int
    private var y : Int
    private var z : Int
    private let xRange : ClosedRange<Int>
    private var index : Int

    init(grid: VoxelGrid, xRange : ClosedRange<Int>, y : Int, z : Int) {
        self.y = y
        self.z = z
        self.xRange = xRange
        
        x = xRange.lowerBound - 1
        index = grid.cellIndex(x: x, y: y, z: z)
    }

    public func next() -> (Int, Int, Int, Int)? {
        x += 1
        index += 1
        if (x > xRange.upperBound) {
            return nil
        } else {
            return (x, y, z, index)
        }
    }

}
