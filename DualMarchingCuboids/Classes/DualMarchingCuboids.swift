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
    
    override public func generatePolygons(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue) {
        
        let before = DispatchTime.now()
        
        while !grid.seedCells.isEmpty {
            let cubeIndex = grid.seedCells.dequeue()!
            
            processCell(grid.cuboids[cubeIndex]!)
        }
        
        let after = DispatchTime.now()
        
        NSLog("Processed grid in %f seconds", Float(after.uptimeNanoseconds - before.uptimeNanoseconds) / Float(1_000_000_000))
        
        interpolateVertices()
        
        let afterInterpolation = DispatchTime.now()
        
        NSLog("Interpolated vertices in %f seconds", Float(afterInterpolation.uptimeNanoseconds - after.uptimeNanoseconds) / Float(1_000_000_000))
    
        triangulateCuboids(&polygons)
        
        let afterTriangulation = DispatchTime.now()
        
        NSLog("Triangulated %d polygon(s) in %f seconds", polygons.count, Float(afterTriangulation.uptimeNanoseconds - afterInterpolation.uptimeNanoseconds) / Float(1_000_000_000))
    }
    
    private func interpolateVertices() {
        for (index, var cuboid) in grid.cuboids {
            if (cuboid.vertex1 == Vector.zero) {
                switch (cuboid.axis) {
                case .xy:
                    
                    // See if there is a cube either in front or behind me
                    let behind = grid.cuboids[index + grid.width * grid.height]
                    let infront = grid.cuboids[index - grid.width * grid.height]
                    NSLog("X Cuboid behind %d in front %d", behind != nil, infront != nil)
                    
                    // Trace the gradient along the X axis
                    let neighbours = cuboid.findNeighboursXY(grid: grid, index: index, faces: cuboid.touchedFaces)
                    cuboid.vertex1 = cuboid.interpolatePositionXY(neighbours: neighbours)
                    
                case .yz:
                    // Trace the gradient along the Z axis
                    let neighbours = cuboid.findNeighboursYZ(grid: grid, index: index, faces: cuboid.touchedFaces)
                    cuboid.vertex1 = cuboid.interpolatePositionYZ(neighbours: neighbours)
                    
                case .none:
                    // See if we can find neighbours to deduce our axis from
                    let xyNeighbours = cuboid.findNeighboursXY(grid: grid, index: index, faces: cuboid.touchedFaces)
                    if !xyNeighbours.filter({ $0 != nil }).isEmpty {
                        // Interpolate from these neighbours
                        cuboid.vertex1 = cuboid.interpolatePositionXY(neighbours: xyNeighbours)
                    } else {
                        let yzNeighbours = cuboid.findNeighboursYZ(grid: grid, index: index, faces: cuboid.touchedFaces)
                        if !yzNeighbours.filter({ $0 != nil }).isEmpty {
                            // Interpolate from these neighbours
                            cuboid.vertex1 = cuboid.interpolatePositionYZ(neighbours: yzNeighbours)
                        } else {
                            // Just use the centre of the cell
                            cuboid.vertex1 = cuboid.centre
                        }
                    }
                    
                case .multiple:
                    // Just use the centre of the cell
                    cuboid.vertex1 = cuboid.centre
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
    
    private func caseFromNeighbours(_ neighbours: [Int]) -> Int {
        var cubeIndex = 0
        for (vertexIndex, value) in neighbours.enumerated() {
            if (value & VoxelGrid.occupiedFlag != 0) {
                cubeIndex |= 1 << vertexIndex
            }
        }
        return cubeIndex
    }
        
    private func processCell(_ cell : Cuboid) {
                
        // Check we haven't already visited this cell
        let index = cell.index(grid: grid)
        let cellData = grid.data[index]
        guard (cellData & DualMarchingCuboids.visitedFlag == 0) else { return }
        grid.data[index] |= DualMarchingCuboids.visitedFlag
                
        assert(cell.width == 1 && cell.height == 1 && cell.depth == 1)
        var cuboid = cell
        
        if (cellData & 0x3 == VoxelAxis.xy.rawValue) {
            
            // Start by growing the cuboid as far in the z axis as we can
            cuboid.axis = .xy
            
        } else if (cellData & 0x3 == VoxelAxis.yz.rawValue) {
            // Start by growing the cuboid as far in the x axis as we can
            cuboid.axis = .yz
                    
        } else if (cellData & 0x3 > 0) {
            // Just output this as a single cuboid for now
            cuboid.axis = .multiple
        } else {
            cuboid.axis = .none
        }
            
        let neighbours = cell.sampleCorners(index: index, grid: grid)
        
        let cubeIndex = caseFromNeighbours(neighbours)
        cuboid.marchingCubesCase = cubeIndex
            
        //check if its completely inside or outside
        guard MarchingCubes.edgeTable[cubeIndex] != 0 else { return }
        
                
        //now build the triangles using triTable
        // Keep track of which faces are included
        let touchedFaces = cuboid.touchedFaces
        
        // Follow the contour into neighbouring cells
        for (n, offset) in MarchingCubes.faceOffsets.enumerated() {
            if (touchedFaces & (1 << n) > 0) {
                let neighbourIndex = index + localFaceOffsets[n]
                                
                if (grid.data[neighbourIndex] & DualMarchingCuboids.visitedFlag == 0) {
                    let neighbour = Cuboid(x: cell.x + offset.0, y: cell.y + offset.1, z: cell.z + offset.2, width: 1, height: 1, depth: 1)
                    if var neighbourCell = grid.addSeed(neighbour) {
                        // Connect neighbours together in a network
                        if (offset.0 > 0) {
                            cuboid.rightNodeIndex = neighbourIndex
                            neighbourCell.leftNodeIndex = index
                            grid.cuboids[neighbourIndex] = neighbourCell
                        } else if (offset.0 < 0) {
                            cuboid.leftNodeIndex = neighbourIndex
                            neighbourCell.rightNodeIndex = index
                            grid.cuboids[neighbourIndex] = neighbourCell
                        } else if (offset.1 > 0) {
                            cuboid.upNodeIndex = neighbourIndex
                            neighbourCell.downNodeIndex = index
                            grid.cuboids[neighbourIndex] = neighbourCell
                        } else if (offset.1 < 0) {
                            cuboid.downNodeIndex = neighbourIndex
                            neighbourCell.upNodeIndex = index
                            grid.cuboids[neighbourIndex] = neighbourCell
                        } else if (offset.2 > 0) {
                            cuboid.forwardsNodeIndex = neighbourIndex
                            neighbourCell.backwardsNodeIndex = index
                            grid.cuboids[neighbourIndex] = neighbourCell
                        } else if (offset.2 < 0) {
                            cuboid.backwardsNodeIndex = neighbourIndex
                            neighbourCell.forwardsNodeIndex = index
                            grid.cuboids[neighbourIndex] = neighbourCell
                        }
                    }
                }
            }
        }
        
        grid.cuboids[index] = cuboid
    }
}
