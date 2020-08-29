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
    static let visitedFlag = 0x4
    
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
    
    private func interpolatePositions(p1: Vector, p2: Vector, v1: Int, v2: Int) -> Vector {
        
        // I don't understand where this number 4.0 comes from,
        // but experimentally it seems to yield the nicest results...
        let targetValue = 1.0 / 4.5
        
        let value1 = v1 >> VoxelGrid.dataBits
        let value2 = v2 >> VoxelGrid.dataBits
        
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
        
        let before = DispatchTime.now()
        
        while !grid.seedCells.isEmpty {
            let cubeIndex = grid.seedCells.dequeue()!
            
            processCell(grid.cuboids[cubeIndex]!)
        }
        
        let after = DispatchTime.now()
        
        NSLog("Processed grid in %f seconds", Float(after.uptimeNanoseconds - before.uptimeNanoseconds) / Float(1_000_000_000))
    
        triangulateCuboids(&polygons)
        
        let afterTriangulation = DispatchTime.now()
        
        NSLog("Triangulated %d polygon(s) in %f seconds", polygons.count, Float(afterTriangulation.uptimeNanoseconds - after.uptimeNanoseconds) / Float(1_000_000_000))
    }
    
    private func triangulateCuboids(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue) {
        
        for (_, cuboid) in grid.cuboids {
            cuboid.triangulate(grid: grid, polygons: &polygons)
        }
        
    }
    
    private func caseFromNeighbours(_ neighbours: [Int]) -> Int {
        var cubeIndex = 0
        for (vertexIndex, value) in neighbours.enumerated() {
            if (value >> VoxelGrid.dataBits != 0) {
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
                
        var cuboid = cell
            
        let neighbours = cell.sampleCorners(index: index, grid: grid)
        
        let cubeIndex = caseFromNeighbours(neighbours)
        cuboid.marchingCubesCase = cubeIndex
        
        if (cuboid.vertex1 == Vector.zero) {
            cuboid.vertex1 = cuboid.corner + cuboid.cellSize * 0.5
        }
            
        //check if its completely inside or outside
        guard MarchingCubes.edgeTable[cubeIndex] != 0 else { return }
        
                
        //now build the triangles using triTable
        // Keep track of which faces are included
        var touchedFaces = 0
        let edges = MarchingCubes.edgeTable[cubeIndex]
        for edgeIndex in 0 ..< 12 {
            if (edges & (1 << edgeIndex) > 0) {
                touchedFaces |= MarchingCubes.edgeFaces[edgeIndex]
            }
        }
        
//        let edgeIndices = (0 ..< 12).filter { edges & (1 << $0) > 0 }
//        let positions = edgeIndices.map { (edgeIndex : Int) -> Vector in
//            touchedFaces |= MarchingCubes.edgeFaces[edgeIndex]
//
//            let edge = MarchingCubes.edgeVertices[edgeIndex]
//
//            let intersectionPoint = interpolatePositions(p1: MarchingCubes.vertexOffsets[edge.0], p2: MarchingCubes.vertexOffsets[edge.1], v1: neighbours[edge.0], v2: neighbours[edge.1]) + corner
//
//            return intersectionPoint
//        }
        
//        let plane = Plane(points: positions)
//
//        if let poly = Polygon(positions.map { Vertex($0, plane?.normal ?? Vector.zero) }, material: UIColor.blue) {
//            polygons.append(poly)
//        }
        
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
