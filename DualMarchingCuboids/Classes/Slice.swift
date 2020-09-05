//
//  Slice.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 24/07/2020.
//

import Foundation
import Euclid

public class Slice : Sequence {
    /*
       5/////2////3
       //  ///  ///
       // / // / //
       4/////0////1
       //  ///  ///
       // / // / //
       6/////7////8
    */
    static let vertexOffsets = [
        Vector( 0,  0, 0),
        Vector( 1,  0, 0),
        Vector( 0,  1, 0),
        Vector( 1,  1, 0),  // Up to here are all 'after' 0
        Vector(-1,  0, 0),
        Vector(-1,  1, 0),
        Vector(-1, -1, 0),
        Vector( 0, -1, 0),
        Vector( 1, -1, 0)
    ]
    static let polygonIndices = [
        [0, 3, 2],
        [0, 1, 3],
        [0, 2, 4],
        [4, 2, 5],
        [0, 4, 6],
        [0, 6, 7],
        [0, 7, 1],
        [1, 7, 8]
    ]
    
    fileprivate let axis : Vector
    public let grid : VoxelGrid
    let rotation : Rotation        
    
    var bounds : VoxelBoundingBox? = nil
    
    public init?(grid: VoxelGrid, rotation: Rotation, axis: Vector) {
        self.grid = grid
        self.rotation = rotation
        self.axis = axis
    }
    
    public var layerDepth : Int {
        return 0
    }
    
    var axisMask : VoxelAxis {
        return .none
    }
    
    public func makeIterator() -> SliceAxisIterator {
        return XYIterator(grid: grid, xRange: (bounds?.min.x ?? 0) ..< (bounds?.max.x ?? grid.width), yRange: (bounds?.min.y ?? 0) ..< (bounds?.max.y ?? grid.height), z: 0)
    }
    
    public func iterator(range1 : Range<Int>, yRange : Range<Int>) -> Iterator {
        return XYIterator(grid: grid, xRange: range1, yRange: yRange, z: 0)
    }
    
    public func perpendicularIndices(range: ClosedRange<Int>) -> [Int] {
        return []
    }
    
    fileprivate func applyVertexOrdering(_ vertexPositions : [Vector]) -> [Vector] {
        return vertexPositions
    }
    
    public func generatePolygons(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue) {
                
        
    }
    
    fileprivate func findNeighbouringData(x : Int, y : Int, z : Int, index : Int) -> [Int] {
        return []
    }
}

public class XYSlice : Slice {
    private let z : Int
    private let zOffset : Double   /// Offset compared to previous layer
    
    public init?(grid: VoxelGrid, z: Int, previousSlice: Slice? = nil) {
        guard z >= 0 && z < grid.depth else { return nil }
            
        let previousXYSlice = previousSlice as? XYSlice
        
        self.z = z
        let previousZ = previousXYSlice?.z ?? 0
        self.zOffset = Double(z - previousZ)
        
        let axis = Vector(0.0, 0.0, zOffset).normalized()
        
        super.init(grid: grid, rotation: Rotation.identity, axis: axis)
    }
    
    override public var layerDepth : Int {
        return z
    }
    
    override var axisMask : VoxelAxis {
        return .xy
    }
    
    override public func makeIterator() -> SliceAxisIterator {
        return XYIterator(grid: grid, xRange: (bounds?.min.x ?? 0) ..< (bounds?.max.x ?? grid.width), yRange: (bounds?.min.y ?? 0) ..< (bounds?.max.y ?? grid.height), z: self.z)
    }
    
    override public func iterator(range1 : Range<Int>, yRange : Range<Int>) -> Iterator {
        return XYIterator(grid: grid, xRange: range1, yRange: yRange, z: self.z)
    }
    
    override public func perpendicularIndices(range: ClosedRange<Int>) -> [Int] {
        return ZIterator(grid: grid, x: 0, y: 0, zRange: range).map { $0.3 }
    }
    
    override fileprivate func findNeighbouringData(x : Int, y : Int, z : Int, index : Int) -> [Int] {
        /*
            5/////2////3
            //  ///  ///
            // / // / //
            4/////0////1
            //  ///  ///
            // / // / //
            6/////7////8
         */
        // See if any of the other eight vertices are available yet
        return [
            grid.data[index],
            x < grid.width ? grid.data[index + 1] : 0,
            y < grid.height ? grid.data[index + grid.width] : 0,
            x < grid.width && y < grid.height ? grid.data[index + 1 + grid.width] : 0,
            x > 0 ? grid.data[index - 1] : 0,
            x > 0 && y < grid.height ? grid.data[index - 1 + grid.width] : 0,
            x > 0 && y > 0 ? grid.data[index - 1 - grid.width] : 0,
            y > 0 ? grid.data[index - grid.width] : 0,
            x < grid.width && y > 0 ? grid.data[index + 1 - grid.width] : 0
        ]
    }
}

public class YZSlice : Slice {
    private let x : Int
    private let xOffset : Double   /// Offset compared to previous layer
    
    public init?(grid: VoxelGrid, x: Int, previousSlice: Slice? = nil) {
        guard x >= 0 && x < grid.width else { return nil }
            
        let previousYZSlice = previousSlice as? YZSlice
        
        self.x = x
        let previousX = previousYZSlice?.x ?? grid.width
        self.xOffset = Double(x - previousX)
        
        let axis = Vector(xOffset, 0.0, 0.0).normalized()
        
        let rotation = Rotation(axis: Vector(0.0, 1.0, 0.0), radians: -Double.pi / 2.0)!
        
        super.init(grid: grid, rotation: rotation, axis: axis)
    }
    
    override public var layerDepth : Int {
        return x
    }
    
    override var axisMask : VoxelAxis {
        return .yz
    }
    
    override public func makeIterator() -> SliceAxisIterator {
        return YZIterator(grid: grid, x: self.x, yRange: (bounds?.min.y ?? 0) ..< (bounds?.max.y ?? grid.height), zRange: (bounds?.min.z ?? 0) ..< (bounds?.max.z ?? grid.depth))
    }
    
    override public func iterator(range1 : Range<Int>, yRange : Range<Int>) -> Iterator {
        return YZIterator(grid: grid, x: self.x, yRange: yRange, zRange: range1)
    }
    
    override public func perpendicularIndices(range: ClosedRange<Int>) -> [Int] {
        return XIterator(grid: grid, xRange: range, y: 0, z: 0).map { $0.3 }
    }
    
    override fileprivate func findNeighbouringData(x : Int, y : Int, z : Int, index : Int) -> [Int] {
        /*
            5/////2////3
            //  ///  ///
            // / // / //
            4/////0////1
            //  ///  ///
            // / // / //
            6/////7////8
         */
        // See if any of the other eight vertices are available yet
        let layerOffset = grid.width * grid.height
        return [
            grid.data[index],
            z < grid.depth ? grid.data[index + layerOffset] : 0,
            y < grid.height ? grid.data[index + grid.width] : 0,
            z < grid.depth && y < grid.height ? grid.data[index + layerOffset + grid.width] : 0,
            z > 0 ? grid.data[index - layerOffset] : 0,
            z > 0 && y < grid.height ? grid.data[index - layerOffset + grid.width] : 0,
            z > 0 && y > 0 ? grid.data[index - layerOffset - grid.width] : 0,
            y > 0 ? grid.data[index - grid.width] : 0,
            z < grid.depth && y > 0 ? grid.data[index + layerOffset - grid.width] : 0
        ]
    }
    
    override fileprivate func applyVertexOrdering(_ vertexPositions : [Vector]) -> [Vector] {
        // It feels like there is a bug lurking here, but I can't understand it yet
        return vertexPositions.reversed()
    }
}
