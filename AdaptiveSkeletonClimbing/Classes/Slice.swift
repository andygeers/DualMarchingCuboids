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
    
    var bounds : VoxelBoundingBox? = nil
    
    public init?(grid: VoxelGrid, previousSlice: Slice?, rotation: Rotation, axis: Vector) {
        self.grid = grid
        self.previousSlice = previousSlice
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
    
    public func perpendicularIndices(range: Range<Int>) -> [Int] {
        return []
    }
    
    fileprivate func applyVertexOrdering(_ vertexPositions : [Vector]) -> [Vector] {
        return vertexPositions
    }
    
    public func generatePolygons(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue) {
                
        for (x, y, z, _, _, index) in self {
            
            let cellData = grid.data[index]
            let depth = cellData >> 2
            let axes = cellData & 0x3
                
            // See if we're newly filled
            if (depth == 1) && (axes == self.axisMask.rawValue) {
                
                let neighbouring = findNeighbouringData(x: x, y: y, z: z, index: index)
                let depths = dataToDepths(neighbouring)
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
    
    fileprivate func findNeighbouringData(x : Int, y : Int, z : Int, index : Int) -> [Int] {
        return []
    }
    
    fileprivate func dataToDepths(_ data : [Int]) -> [Int] {
        let mask = self.axisMask.rawValue
        
        return data.map { (d : Int) in
            // Only return depths in the same axis
            if (d & 0x3 == mask) {
                return d >> 2
            } else {
                return 0
            }
        }
    }
}

public class XYSlice : Slice {
    private let z : Int
    private let zOffset : Double   /// Offset compared to previous layer
    
    public init?(grid: VoxelGrid, z: Int, previousSlice: Slice? = nil) {
        guard z >= 0 && z < grid.depth else { return nil }
            
        let previousXYSlice = previousSlice as? XYSlice
        
        self.z = z
        let previousZ = previousXYSlice?.z ?? grid.depth
        self.zOffset = Double(z - previousZ)
        
        let axis = Vector(0.0, 0.0, zOffset).normalized()
        
        super.init(grid: grid, previousSlice: previousSlice, rotation: Rotation.identity, axis: axis)
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
    
    override public func perpendicularIndices(range: Range<Int>) -> [Int] {
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
        
        let rotation = Rotation(axis: Vector(0.0, 1.0, 0.0), radians: Double.pi / 2.0)!
        
        super.init(grid: grid, previousSlice: previousSlice, rotation: rotation, axis: axis)
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
    
    override public func perpendicularIndices(range: Range<Int>) -> [Int] {
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

public class MarchingCubesSlice : XYSlice {
    
    override var axisMask : VoxelAxis {
        return .multiple
    }
    
    override fileprivate func findNeighbouringData(x: Int, y: Int, z: Int, index: Int) -> [Int] {
        
        let nextZ = grid.width * grid.height
        let nextY = grid.width
        
        return [
            grid.data[index],
            z > 0 ? grid.data[index - nextZ] : 0,
            x + 1 < grid.width && z > 0 ? grid.data[index - nextZ + 1] : 0,
            x + 1 < grid.width ? grid.data[index + 1] : 0,
            y + 1 < grid.height ? grid.data[index + nextY] : 0,
            y + 1 < grid.height && z > 0 ? grid.data[index - nextZ + nextY] : 0,
            x + 1 < grid.width && y + 1 < grid.height && z > 0 ? grid.data[index - nextZ + 1 + nextY] : 0,
            x + 1 < grid.width && y + 1 < grid.height ? grid.data[index + 1 + nextY] : 0
        ]
    }
    
    private func interpolatePositions(p1: Vector, p2: Vector, v1: Int, v2: Int) -> Vector {
        
        // I don't understand where this number 4.0 comes from,
        // but experimentally it seems to yield the nicest results...
        let targetValue = 1.0 / 4.0        
        
        let value1 = v1 >> 2
        let value2 = v2 >> 2
        
        assert((value1 == 0 || value2 == 0) && (value1 != 0 || value2 != 0))
        
        let diff = Double(value2 - value1) / 255.0
        let offset : Double
        if (diff >= 0.0) {
            offset = Swift.min(targetValue / diff, 1.0)
        } else {
            offset = Swift.max(1.0 + targetValue / diff, 0.0)
        }
        let direction = p2 - p1
                
        assert(offset >= 0.0 && offset <= 1.0)
        
        return p1 + direction * offset
    }
    
    override public func generatePolygons(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue) {
                
        for (x, y, z, _, _, index) in self {
            
            let neighbours = findNeighbouringData(x: x, y: y, z: z, index: index)
            
            var cubeIndex = 0
            for (vertexIndex, value) in neighbours.enumerated() {
                if (value >> 2 != 0) {
                    cubeIndex |= 1 << vertexIndex
                }
            }
            //Where cubeindex |= 2^i means that ith bit of cubeindex is set to 1
            
            let centre = Vector(Double(x), Double(y), Double(z))                        
            
            //check if its completely inside or outside
            guard MarchingCubes.edgeTable[cubeIndex] != 0 else { continue }
            //guard wasMixed else { continue }

            //now build the triangles using triTable
            for n in stride(from: 0, to: MarchingCubes.triTable[cubeIndex].count, by: 3) {
                
                let edges = [
                    MarchingCubes.edgeVertices[MarchingCubes.triTable[cubeIndex][n]],
                    MarchingCubes.edgeVertices[MarchingCubes.triTable[cubeIndex][n + 1]],
                    MarchingCubes.edgeVertices[MarchingCubes.triTable[cubeIndex][n + 2]]
                ]
                
                let positions = edges.map { interpolatePositions(p1: MarchingCubes.vertexOffsets[$0[0]], p2: MarchingCubes.vertexOffsets[$0[1]], v1: neighbours[$0[0]], v2: neighbours[$0[1]]) + centre }
                
                let plane = Plane(points: positions)
                
                if let poly = Polygon(positions.map { Vertex($0, plane?.normal ?? Vector.zero) }, material: UIColor.blue) {
                    polygons.append(poly)
                }
            }
        }
    }
        
}
