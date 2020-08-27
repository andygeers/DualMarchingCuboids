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
    
    private var octree : Octree
    
    public init?(grid: VoxelGrid) {
        octree = Octree(grid: grid)
        
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
    
    static func findCellCorners(grid: VoxelGrid, x: Int, y: Int, z: Int, index: Int, width: Int = 1, height: Int = 1, depth: Int = 1) -> [Int] {
        
        let nextZ = grid.width * grid.height * depth
        let nextY = grid.width * height
        
        return [
            grid.data[index],
            z + depth < grid.depth ? grid.data[index + nextZ] : 0,
            x + width < grid.width && z + depth < grid.depth ? grid.data[index + nextZ + width] : 0,
            x + width < grid.width ? grid.data[index + width] : 0,
            y + height < grid.height ? grid.data[index + nextY] : 0,
            y + height < grid.height && z + depth < grid.depth ? grid.data[index + nextZ + nextY] : 0,
            x + width < grid.width && y + height < grid.height && z + depth < grid.depth ? grid.data[index + nextZ + width + nextY] : 0,
            x + width < grid.width && y + height < grid.height ? grid.data[index + width + nextY] : 0
        ]
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
        
        for (currentCell, position) in grid.seedCells {
            let (x, y, z) = grid.positionFromIndex(currentCell)
            
            processCell(x: x, y: y, z: z)
            
            // Move to the next seed
            currentCell = grid.seedCells.first ?? -1
        }
        
        let after = DispatchTime.now()
        
        NSLog("Processed grid in %f seconds", polygons.count, Float(after.uptimeNanoseconds - before.uptimeNanoseconds) / Float(1_000_000_000))
    
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
        
    private func processCell(x: Int, y: Int, z: Int) {
                
        var index = grid.cellIndex(x: x, y : y, z: z)
        
        // Check we haven't already visited this cell
        let cellData = grid.data[index]
        guard (cellData & DualMarchingCuboids.visitedFlag == 0) else { return }
        grid.data[index] |= DualMarchingCuboids.visitedFlag
        
        var width = 1
        var height = 1
        var depth = 1
        var matchCase = -1
        
        let axes : [Int]
        let cuboid : Cuboid
        
        if (cellData & 0x3 == VoxelAxis.xy.rawValue) {
            
            // Start by growing the cuboid as far in the z direction as we can
            
        } else if (cellData & 0x3 == VoxelAxis.yz.rawValue) {
            // Start by growing the cuboid as far in the -x direction as we can
            // TODO: It actually does make a difference which way the wall points as to
            // the quality of the results
            
        } else {
            // Just output this as a single cuboid for now
        }
            
        let neighbours = DualMarchingCuboids.findCellCorners(grid: grid, x: x, y: y, z: z, index: index, width: width, height: height, depth: depth)
        
        let cubeIndex = caseFromNeighbours(neighbours)
            
        //check if its completely inside or outside
        guard MarchingCubes.edgeTable[cubeIndex] != 0 else { return }
        
        cuboid = Cuboid(index: index, width: width, height: height, depth: depth, marchingCubesCase: cubeIndex)
        
        let corner = Vector(Double(x), Double(y), Double(z))
        let cellSize = Vector(Double(width), Double(height), Double(depth))
        
        
                
        //now build the triangles using triTable
        // Keep track of which faces are included
        var touchedFaces = 0
        let edges = MarchingCubes.edgeTable[cubeIndex]
        let edgeIndices = (0 ..< 12).filter { edges & (1 << $0) > 0 }
        let positions = edgeIndices.map { (edgeIndex : Int) -> Vector in
            touchedFaces |= MarchingCubes.edgeFaces[edgeIndex]
            
            let edge = MarchingCubes.edgeVertices[edgeIndex]
            
            let intersectionPoint = interpolatePositions(p1: MarchingCubes.vertexOffsets[edge.0], p2: MarchingCubes.vertexOffsets[edge.1], v1: neighbours[edge.0], v2: neighbours[edge.1]) + corner
            
            return intersectionPoint
        }
        
        let plane = Plane(points: positions)
        
        if let poly = Polygon(positions.map { Vertex($0, plane?.normal ?? Vector.zero) }, material: UIColor.blue) {
            polygons.append(poly)
        }
        
        // Follow the contour into neighbouring cells
        for (n, offset) in localFaceOffsets.enumerated() {
            if (touchedFaces & (1 << n) > 0) {
                let neighbour = index + offset
                
                if (grid.data[neighbour] & DualMarchingCuboids.visitedFlag == 0) {
                    grid.addSeed(neighbour)
                }
            }
        }
    }
}
