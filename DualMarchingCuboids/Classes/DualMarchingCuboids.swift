//
//  DualMarchingCuboids.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 27/08/2020.
//

import Foundation
import Euclid

public class DualMarchingCuboids : Slice {
    
    let localFaceOffsets : [Int]
    static let visitedFlag = 0x8
    
    public init?(grid: VoxelGrid) {
        localFaceOffsets = DualMarchingCuboids.calculateFaceOffsets(grid: grid)
        
        super.init(grid: grid, rotation: Rotation.identity, axis: Vector(0.0, 0.0, -1.0))
    }
    
    private static func calculateFaceOffsets(grid: VoxelGrid) -> [Int] {
        return MarchingCubes.faceOffsets.map { (x : Int, y : Int, z : Int) in
            x + y * grid.width + z * grid.width * grid.height
        }
    }
    
    override var axisMask : VoxelAxis {
        return .multiple
    }
    
    override public func generatePolygons(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue, progressCallback: ((Double) -> Void)? = nil) {
        
        let before = DispatchTime.now()
        
        while !grid.seedCells.isEmpty {
            let cubeIndex = grid.seedCells.dequeue()!
            
            if let cuboid = grid.cuboids[cubeIndex] {
                processCell(cuboid)
            }
        }
        
        let after = DispatchTime.now()
        
        NSLog("Processed grid in %f seconds", Float(after.uptimeNanoseconds - before.uptimeNanoseconds) / Float(1_000_000_000))
        
        grid.mergeCuboids(progressCallback: progressCallback)
        
        let afterMerge = DispatchTime.now()
        
        NSLog("Merged cuboids in %f seconds", Float(afterMerge.uptimeNanoseconds - after.uptimeNanoseconds) / Float(1_000_000_000))
        
        interpolateVertices()
        
        let afterInterpolation = DispatchTime.now()
        
        NSLog("Interpolated vertices in %f seconds", Float(afterInterpolation.uptimeNanoseconds - afterMerge.uptimeNanoseconds) / Float(1_000_000_000))
    
        triangulateCuboids(&polygons, material: material)
        
        let afterTriangulation = DispatchTime.now()
        
        NSLog("Triangulated %d polygon(s) in %f seconds", polygons.count, Float(afterTriangulation.uptimeNanoseconds - afterInterpolation.uptimeNanoseconds) / Float(1_000_000_000))
        
        NSLog("Total time %f seconds", Float(afterTriangulation.uptimeNanoseconds - before.uptimeNanoseconds) / Float(1_000_000_000))
    }
    
    private func interpolateVertices() {
        for (index, var cuboid) in grid.cuboids {
            if (cuboid.vertex1 == Vector.zero) {
                switch (cuboid.axis) {
                case .xy:
                    
                    // See if there is a cube either in front or behind me
                    let behind = grid.cuboids[index + grid.width * grid.height]
                    let infront = grid.cuboids[index - grid.width * grid.height]                    
                    
                    // Trace the gradient along the X axis
                    let neighbours = cuboid.findNeighboursXY(grid: grid, index: index, faces: cuboid.touchedFaces)
                    cuboid.vertex1 = cuboid.interpolatePositionXY(neighbours: neighbours, grid: grid)
                    
                case .yz:
                    // Trace the gradient along the Z axis
                    let neighbours = cuboid.findNeighboursYZ(grid: grid, index: index, faces: cuboid.touchedFaces)
                    cuboid.vertex1 = cuboid.interpolatePositionYZ(neighbours: neighbours, grid: grid)
                    
                case .none:
                    // See if we can find neighbours to deduce our axis from
                    let xyNeighbours = cuboid.findNeighboursXY(grid: grid, index: index, faces: cuboid.touchedFaces)
                    if !xyNeighbours.filter({ $0 != nil }).isEmpty {
                        // Interpolate from these neighbours
                        cuboid.vertex1 = cuboid.interpolatePositionXY(neighbours: xyNeighbours, grid: grid)
                    } else {
                        let yzNeighbours = cuboid.findNeighboursYZ(grid: grid, index: index, faces: cuboid.touchedFaces)
                        if !yzNeighbours.filter({ $0 != nil }).isEmpty {
                            // Interpolate from these neighbours
                            cuboid.vertex1 = cuboid.interpolatePositionYZ(neighbours: yzNeighbours, grid: grid)
                        } else {
                            // Just use the centre of the cell
                            cuboid.vertex1 = cuboid.surfaceCentre(grid: grid)
                        }
                    }
                    
                case .multiple:
                    // Just use the centre of the cell
                    cuboid.vertex1 = cuboid.surfaceCentre(grid: grid)
                }
                
                grid.cuboids[index] = cuboid
            }
        }
    }
    
    private func triangulateCuboids(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue) {
        
        for (_, cuboid) in grid.cuboids {
            cuboid.triangulate(grid: grid, polygons: &polygons, material: material)
        }
        
    }
    
    private func isUglyCorner(cuboid: Cuboid, frontCell: Cuboid, touchedFaces: Int) -> Bool {
        // The ugly corners are the ones where:
        // 1. They have a seed cube 'in front'
        guard frontCell.vertex1 != Vector.zero else { return false }
                
        // 2. They are a corner - i.e. they go either up-down or side-side from here
        switch (cuboid.axis) {
        case .xy:
            // 1 3 4 5
            return (touchedFaces & (1 << 1) > 0) || (touchedFaces & (1 << 3) > 0) ||
                (touchedFaces & (1 << 4) > 0) || (touchedFaces & (1 << 5) > 0)
        case .yz:
            // 0 2 4 5
            return (touchedFaces & (1 << 0) > 0) || (touchedFaces & (1 << 2) > 0) ||
                (touchedFaces & (1 << 4) > 0) || (touchedFaces & (1 << 5) > 0)
        default:
            return false
        }
    }
        
    private func processCell(_ cell : Cuboid) {
                
        // Check we haven't already visited this cell
        let index = cell.index(grid: grid)
        let cellData = grid.data[index]
        guard (cellData & DualMarchingCuboids.visitedFlag == 0) else { return }
        grid.data[index] |= DualMarchingCuboids.visitedFlag
                
        assert(cell.width == 1 && cell.height == 1 && cell.depth == 1)
        var cuboid = cell
            
        let neighbours = cell.sampleCorners(index: index, grid: grid)
        
        let cubeIndex = Cuboid.caseFromNeighbours(neighbours)
        cuboid.marchingCubesCase = cubeIndex
        
        var grownIndex = index
        
        // Keep track of where the actual surface is, for when we generate vertices
        cuboid.seedIndex = index
        cuboid.seedIndexMax = index
        
        //check if its completely inside or outside
        guard MarchingCubes.edgeTable[cubeIndex] != 0 else { return }
        
        cuboid.axis = VoxelAxis(rawValue: cellData & 0x3)!
                
        //now build the triangles using triTable
        // Keep track of which faces are included
        let touchedFaces = cuboid.touchedFaces
        
        // Follow the contour into neighbouring cells
        for (n, offset) in MarchingCubes.faceOffsets.enumerated() {
            if (touchedFaces & (1 << n) > 0) {
                var neighbourSurfaceIndex = index + localFaceOffsets[n]
                while (cuboid.containsIndex(neighbourSurfaceIndex, grid: grid)) {
                    neighbourSurfaceIndex += localFaceOffsets[n]
                }
                                
                if (grid.data[neighbourSurfaceIndex] & DualMarchingCuboids.visitedFlag == 0) {
                    let neighbour = Cuboid(grid: grid, index: neighbourSurfaceIndex, width: 1, height: 1, depth: 1)
                    grid.addSeed(neighbour)
                }
            }
        }
        
        if (cuboid.axis == .xy), let frontCuboid = cuboid.findNeighbour(direction: .z, grid: grid) {
            // This might form an ugly corner - let's see
            if isUglyCorner(cuboid: cuboid, frontCell: frontCuboid, touchedFaces: touchedFaces) {
                grid.uglyCubes.append(index)
            }
        } else if (cuboid.axis == .yz), let frontCuboid = cuboid.findNeighbour(direction: .x, grid: grid) {
            // This might form an ugly corner - let's see
            if isUglyCorner(cuboid: cuboid, frontCell: frontCuboid, touchedFaces: touchedFaces) {
                grid.uglyCubes.append(index)
            }
        }
        
        // Make all cells within the cuboid point to this index
        cuboid.markGridIndices(grid: grid)        
    }
}
