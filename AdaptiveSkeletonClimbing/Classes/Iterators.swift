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
        index = x + y * grid.width + z * (grid.width * grid.height)
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

    public func next() -> (Int, Int, Int, Int)? {
        z += 1
        index += layerOffset
        if (z >= zRange.upperBound) {
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
        
        index = x + y * grid.width + z * (grid.width * grid.height)
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
            
            index = x + y * grid.width + z * (grid.width * grid.height)
        }
        
        return (x, y, z, z, y, index)
    }
}

public class XIterator : IteratorProtocol, Sequence {

    private var x : Int
    private var y : Int
    private var z : Int
    private let xRange : Range<Int>
    private var index : Int

    init(grid: VoxelGrid, xRange : Range<Int>, y : Int, z : Int) {
        self.y = y
        self.z = z
        self.xRange = xRange
        
        x = xRange.lowerBound - 1
        index = x + y * grid.width + z * (grid.width * grid.height)
    }

    public func next() -> (Int, Int, Int, Int)? {
        x += 1
        index += 1
        if (x >= xRange.upperBound) {
            return nil
        } else {
            return (x, y, z, index)
        }
    }

}

public struct SlicesIterator : IteratorProtocol {
    let grid : VoxelGrid
    var currentSliceIndex : Int
    var previousSlice : Slice? = nil
    var boundingBox : VoxelBoundingBox
    var boundingBoxIndex : Int
    
    public init(grid: VoxelGrid) {
        self.grid = grid
        
        boundingBoxIndex = 0
        guard boundingBoxIndex < grid.boundingBoxes.count else {
            currentSliceIndex = Int.max
            boundingBox = VoxelBoundingBox(min: VoxelCoordinates.zero, max: VoxelCoordinates.zero, axis: .none)
            return
        }
        
        boundingBox = grid.boundingBoxes[boundingBoxIndex]
        
        //currentSliceIndex = grid.depth - 1
        currentSliceIndex = boundingBox.finalIndex + 1
    }
    
    public mutating func next() -> Slice? {
        currentSliceIndex -= 1
        
        while (currentSliceIndex < boundingBox.firstIndex) {
            nextBoundingBox()
        }
        
        var currentSlice : Slice? = nil
        
        while (currentSlice == nil) {
            switch (boundingBox.axis) {
            case .xy:
                currentSlice = XYSlice(grid: grid, z: currentSliceIndex, previousSlice: previousSlice)
                
            case .yz:
                currentSlice = YZSlice(grid: grid, x: currentSliceIndex, previousSlice: previousSlice)
                
            case .multiple:
                currentSlice = MarchingCubesSlice(grid: grid)
                    
            default:
                return nil
            }
            
            if (currentSlice == nil) {
                nextBoundingBox()
            }
            
            previousSlice = currentSlice
        }
        return currentSlice
    }
    
    private mutating func nextBoundingBox() {
        boundingBoxIndex += 1
        if (boundingBoxIndex >= grid.boundingBoxes.count) {
            currentSliceIndex = Int.max
            boundingBox = VoxelBoundingBox(min: VoxelCoordinates.zero, max: VoxelCoordinates.zero, axis: .none)
            return
        }
        boundingBox = grid.boundingBoxes[boundingBoxIndex]
        currentSliceIndex = boundingBox.finalIndex
        previousSlice = nil
    }
}
