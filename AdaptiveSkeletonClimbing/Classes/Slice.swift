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
    fileprivate let previousSlice : Slice?
    fileprivate let rotation : Rotation
    
    public init?(grid: VoxelGrid, previousSlice: Slice?, rotation: Rotation, axis: Vector) {
        self.grid = grid
        self.previousSlice = previousSlice
        self.rotation = rotation
        self.axis = axis
    }
    
    public var layerDepth : Int {
        get {
            return 0
        }
    }
    
    public func makeIterator() -> SliceAxisIterator {
        return XYIterator(grid: grid, xRange: 0 ..< grid.width, yRange: 0 ..< grid.height, z: 0)
    }
    
    public func iterator(range1 : Range<Int>, yRange : Range<Int>) -> Iterator {
        return XYIterator(grid: grid, xRange: range1, yRange: yRange, z: 0)
    }
    
    public func perpendicularIndices(range: Range<Int>) -> [Int] {
        return []
    }
    
    fileprivate func applyVertexOrdering(_ vertexPositions : [Vector]) -> [Vector] {
        return vertexPositions
    }
    
    public func generatePolygons(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue) {
                
        NSLog("Offset 1 is %@", String(describing: Slice.vertexOffsets[1].rotated(by: self.rotation)))
        
        for (x, y, z, _, _, index) in self {
            
            let depth = grid.data[index]
                
            // See if we're newly filled
            if (depth == 1) {
                
                let depths = findNeighbouringDepths(x: x, y: y, z: z, index: index)
                let centre = Vector(Double(x), Double(y), Double(z))
                
                // We will include a polygon if:
                //    a) All the corners are present
                //AND b) The corners are 'after' our vertex
                // OR c) At least one of the corners is from a previous layer
                let polyIndices = Slice.polygonIndices.filter { (indices) in
                    indices.allSatisfy({ depths[$0] > 0 }) &&
                    indices.contains(where: { $0 <= 3 || depths[$0] > depths[0] })
                }
                let vertexPositions = polyIndices.map { (indices) in
                    applyVertexOrdering(indices.map { centre + Slice.vertexOffsets[$0].rotated(by: self.rotation) - self.axis * (Double(depths[$0] - 1)) })
                }
                for positions in vertexPositions {
                    if let poly = Polygon(positions.map { Vertex($0, Vector.zero) }, material: material) {
                        polygons.append(poly)
                    }
                }
            }
        }
    }
    
    fileprivate func findNeighbouringDepths(x : Int, y : Int, z : Int, index : Int) -> [Int] {
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
        let previousZ = (previousXYSlice?.z ?? (z == 0 ? -1 : grid.depth))
        self.zOffset = Double(z - previousZ)
        
        let axis = Vector(0.0, 0.0, zOffset)
        
        super.init(grid: grid, previousSlice: previousSlice, rotation: Rotation.identity, axis: axis)
    }
    
    override public var layerDepth : Int {
        get {
            return z
        }
    }
    
    override public func makeIterator() -> SliceAxisIterator {
        return XYIterator(grid: grid, xRange: 0 ..< grid.width, yRange: 0 ..< grid.height, z: self.z)
    }
    
    override public func iterator(range1 : Range<Int>, yRange : Range<Int>) -> Iterator {
        return XYIterator(grid: grid, xRange: range1, yRange: yRange, z: 0)
    }
    
    override public func perpendicularIndices(range: Range<Int>) -> [Int] {
        return ZIterator(grid: grid, x: 0, y: 0, zRange: range).map { $0.3 }
    }
    
    override fileprivate func findNeighbouringDepths(x : Int, y : Int, z : Int, index : Int) -> [Int] {
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
        let previousX = (previousYZSlice?.x ?? (x == 0 ? -1 : grid.width))
        self.xOffset = Double(x - previousX)
        
        let axis = Vector(xOffset, 0.0, 0.0)
        
        let rotation = Rotation(axis: Vector(0.0, 1.0, 0.0), radians: Double.pi / 2.0)!
        
        super.init(grid: grid, previousSlice: previousSlice, rotation: rotation, axis: axis)
    }
    
    override public var layerDepth : Int {
        get {
            return x
        }
    }
    
    override public func makeIterator() -> SliceAxisIterator {
        return YZIterator(grid: grid, x: self.x, yRange: 0 ..< grid.height, zRange: 0 ..< grid.depth)
    }
    
    override public func iterator(range1 : Range<Int>, yRange : Range<Int>) -> Iterator {
        return YZIterator(grid: grid, x: 0, yRange: yRange, zRange: range1)
    }
    
    override public func perpendicularIndices(range: Range<Int>) -> [Int] {
        return XIterator(grid: grid, xRange: range, y: 0, z: 0).map { $0.3 }
    }
    
    override fileprivate func findNeighbouringDepths(x : Int, y : Int, z : Int, index : Int) -> [Int] {
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
