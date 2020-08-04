//
//  Slice.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 24/07/2020.
//

import Foundation
import Euclid

public class Slice {
    private let z : Int
    private let zOffset : Double   /// Offset compared to previous layer
    public let offset : Int
    private let contourTracer : VoxelGrid
    private let previousSlice : Slice?
    
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
    
    public init?(contourTracer: VoxelGrid, z: Int, previousSlice: Slice?) {
        guard z >= 0 && z < contourTracer.depth else { return nil }
            
        self.z = z
        let previousZ = (previousSlice?.z ?? (z == 0 ? -1 : contourTracer.depth))
        self.zOffset = Double(z - previousZ)
        self.contourTracer = contourTracer
        self.previousSlice = previousSlice
        
        if (z == -1 || z == contourTracer.depth) {
            self.offset = -1
        } else {
            self.offset = z * (contourTracer.width * contourTracer.height)
        }
    }
    
    public func generatePolygons(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue) {
                
        for (x, y, z, index) in XYIterator(grid: contourTracer, xRange: 0 ..< contourTracer.width, yRange: 0 ..< contourTracer.height, z: self.z) {
            
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
                    indices.map { centre + Slice.vertexOffsets[$0] - Vector(0.0, 0.0, (Double(depths[$0] - 1) * zOffset)) }
                }
                for positions in vertexPositions {
                    if let poly = Polygon(positions.map { Vertex($0, Vector.zero) }, material: material) {
                        polygons.append(poly)
                    }
                }
            }
        }
    }
    
    private func findNeighbouringDepths(x : Int, y : Int, z : Int, index : Int) -> [Int] {
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
