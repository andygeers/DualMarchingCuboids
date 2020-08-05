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
    
    public let offset : Int
    fileprivate let axis : Vector
    fileprivate let contourTracer : VoxelGrid
    fileprivate let previousSlice : Slice?
    fileprivate let rotation : Rotation
    
    public init?(contourTracer: VoxelGrid, previousSlice: Slice?, offset: Int, rotation: Rotation, axis: Vector) {
        self.contourTracer = contourTracer
        self.previousSlice = previousSlice
        self.offset = offset
        self.rotation = rotation
        self.axis = axis
    }
    
    public func makeIterator() -> XYIterator {
        return XYIterator(grid: contourTracer, xRange: 0 ..< contourTracer.width, yRange: 0 ..< contourTracer.height, z: 0)
    }
    
    public func generatePolygons(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue) {
                
        for (x, y, z, index) in self {
            
            let depth = contourTracer.data[index]
                
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
                    indices.map { centre + Slice.vertexOffsets[$0].rotated(by: self.rotation) - self.axis * (Double(depths[$0] - 1)) }
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
    
    public init?(contourTracer: VoxelGrid, z: Int, previousSlice: Slice?) {
        guard z >= 0 && z < contourTracer.depth else { return nil }
            
        let previousXYSlice = previousSlice as? XYSlice
        
        self.z = z
        let previousZ = (previousXYSlice?.z ?? (z == 0 ? -1 : contourTracer.depth))
        self.zOffset = Double(z - previousZ)
        
        let offset : Int
        if (z == -1 || z == contourTracer.depth) {
            offset = -1
        } else {
            offset = z * (contourTracer.width * contourTracer.height)
        }
        
        let axis = Vector(0.0, 0.0, zOffset)
        
        super.init(contourTracer: contourTracer, previousSlice: previousSlice, offset: offset, rotation: Rotation.identity, axis: axis)
    }
    
    override public func makeIterator() -> XYIterator {
        return XYIterator(grid: contourTracer, xRange: 0 ..< contourTracer.width, yRange: 0 ..< contourTracer.height, z: self.z)
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
            contourTracer.data[index],
            x < contourTracer.width ? contourTracer.data[index + 1] : 0,
            y < contourTracer.height ? contourTracer.data[index + contourTracer.width] : 0,
            x < contourTracer.width && y < contourTracer.height ? contourTracer.data[index + 1 + contourTracer.width] : 0,
            x > 0 ? contourTracer.data[index - 1] : 0,
            x > 0 && y < contourTracer.height ? contourTracer.data[index - 1 + contourTracer.width] : 0,
            x > 0 && y > 0 ? contourTracer.data[index - 1 - contourTracer.width] : 0,
            y > 0 ? contourTracer.data[index - contourTracer.width] : 0,
            x < contourTracer.width && y > 0 ? contourTracer.data[index + 1 - contourTracer.width] : 0
        ]
    }
}
