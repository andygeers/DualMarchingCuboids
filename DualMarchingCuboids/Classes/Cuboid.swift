//
//  Cuboid.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 27/08/2020.
//

import Foundation
import Euclid

fileprivate func randomColor() -> UIColor {
    return UIColor(red: CGFloat.random(in: 0 ... 1.0), green: CGFloat.random(in: 0 ... 1.0), blue: CGFloat.random(in: 0 ... 1.0), alpha: 0.7)
}

extension Array {
    func reversedIf(_ condition : Bool) -> Array {
        if (condition) {
            return reversed()
        } else {
            return self
        }
    }
}

public struct Cuboid {
    var x : Int
    var y : Int
    var z : Int
    
    func index(grid: VoxelGrid) -> Int {
        return z * grid.width * grid.height + y * grid.width + x
    }
    
    var width : Int
    var height : Int
    var depth : Int
    
    var seedIndex : Int = -1
    var seedIndexMax : Int = -1
    
    var isUnitCube : Bool {
        return width == 1 && height == 1 && depth == 1
    }
    
    var marchingCubesCase : Int = -1
    
    var zeroEdges : Int {
        return MarchingCubes.edgeTable[marchingCubesCase]
    }
    
    var touchedFaces : Int {
        guard marchingCubesCase >= 0 else { return 0 }
        
        var touchedFaces = 0
        let edges = MarchingCubes.edgeTable[marchingCubesCase]
        for edgeIndex in 0 ..< 12 {
            if (edges & (1 << edgeIndex) > 0) {
                touchedFaces |= MarchingCubes.edgeFaces[edgeIndex]
            }
        }
        return touchedFaces
    }
    
    var axis : VoxelAxis = .none
    
    // There can be up to four discreet surfaces
    // in the most complex Marching Cubes case
    public var vertex1 : Vector = Vector.zero
    var vertex2 : Vector = Vector.zero
    var vertex3 : Vector = Vector.zero
    var vertex4 : Vector = Vector.zero
    
    public var surfaceNormal : Vector = Vector.zero
    
    func sampleMarchingCubesCaseIfMissing(grid: VoxelGrid) -> Int {
        guard marchingCubesCase < 0 else { return marchingCubesCase }
        
        let index = self.index(grid: grid)
        let neighbours = sampleCorners(index: index, grid: grid)
        
        return Cuboid.caseFromNeighbours(neighbours)
    }
    
    mutating func appendVertex(_ vertex: Vector) {
        guard vertex != Vector.zero else { return }
        
        if (vertex1 == Vector.zero) {
            vertex1 = vertex
        } else if (vertex2 == Vector.zero) {
            vertex2 = vertex
        } else if (vertex3 == Vector.zero) {
            vertex3 = vertex
        } else if (vertex4 == Vector.zero) {
            vertex4 = vertex
        } else {
            let corner = Vector(Double(x), Double(y), Double(z))
            let cellSize = Vector(Double(width), Double(height), Double(depth))
            let centre = corner + cellSize * 0.5
            
            vertex1 = centre
            vertex2 = Vector.zero
            vertex3 = Vector.zero
            vertex4 = Vector.zero
        }
    }
    
    var corner : Vector {
        return Vector(Double(x), Double(y), Double(z))
    }
    var cellSize : Vector {
        return Vector(Double(width), Double(height), Double(depth))
    }
    var centre : Vector {
        return corner + cellSize * 0.5
    }
    
    func surfaceCentre(grid: VoxelGrid) -> Vector {
        guard seedIndex != -1 else {
            assert(width == 1 && height == 1 && depth == 1)
            return centre
        }
        let (x1, y1, z1) = grid.positionFromIndex(seedIndex)
        let (x2, y2, z2) = grid.positionFromIndex(seedIndexMax)
        return Vector((Double(x1) + Double(x2 + 1)) / 2.0, (Double(y1) + Double(y2 + 1)) / 2.0, (Double(z1) + Double(z2 + 1)) / 2.0)
    }
    
    var bounds : Bounds {
        return Bounds(min: corner, max: corner + cellSize)
    }
    
    func containsIndex(_ index : Int, grid: VoxelGrid) -> Bool {
        let (x, y, z) = grid.positionFromIndex(index)        
        return x >= self.x && x < self.x + self.width && y >= self.y && y < self.y + self.height && z >= self.z && z < self.z + self.depth
    }
    
    public func mesh(grid: VoxelGrid) -> Mesh {
        let centre = corner + cellSize * 0.5
        let cuboid = Mesh.cube(center: Vector.zero, size: 1.0, faces: .front, material: randomColor()).scaled(by: cellSize).translated(by: centre)
        return cuboid
    }
    
    internal static func caseFromNeighbours(_ neighbours: [Int]) -> Int {
        var cubeIndex = 0
        for (vertexIndex, value) in neighbours.enumerated() {
            if (value & VoxelGrid.occupiedFlag != 0) {
                cubeIndex |= 1 << vertexIndex
            }
        }
        return cubeIndex
    }
    
    func sampleCorners(index: Int, grid: VoxelGrid) -> [Int] {
        
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
}

extension Cuboid {
    init(grid: VoxelGrid, index: Int, width: Int, height: Int, depth: Int) {
        let (x, y, z) = grid.positionFromIndex(index)        
        self.init(x: x, y: y, z: z, width: width, height: height, depth: depth)
    }
}
