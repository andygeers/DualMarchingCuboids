//
//  Cuboid.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 27/08/2020.
//

import Foundation
import Euclid

fileprivate func randomColor() -> UIColor {
    return UIColor(red: CGFloat.random(in: 0 ... 1.0), green: CGFloat.random(in: 0 ... 1.0), blue: CGFloat.random(in: 0 ... 1.0), alpha: 0.5)
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
    
    // There may of course be a lot of nodes along each edge, for large cuboids,
    // but we can find all of the others by traversing from the first one on that edge
    var upNodeIndex : Int = -1
    var rightNodeIndex : Int = -1
    var downNodeIndex : Int = -1
    var leftNodeIndex : Int = -1
    var forwardsNodeIndex : Int = -1
    var backwardsNodeIndex : Int = -1
    
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
        let (x, y, z) = grid.positionFromIndex(seedIndex)
        return Vector(Double(x) + 0.5, Double(y) + 0.5, Double(z) + 0.5)
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
    
    func interpolatePositionXY(from neighbour: Cuboid, grid: VoxelGrid) -> Vector {
        assert(neighbour.x != x || neighbour.y != y || neighbour.z != z)
        assert(neighbour.vertex1 != Vector.zero)
        
        var pos = centre
        
        if (neighbour.surfaceNormal == Vector.zero) {
            // No serious interpolation possible, just use the same Z
            pos.z = neighbour.vertex1.z
        } else {
                
            //assert(neighbour.z == z)
            
            // Do some linear interpolation of the surface normal
            // Equation is plane.normal.x * x + plane.normal.y * y + plane.normal.z * z = plane.w
            let normal = neighbour.surfaceNormal
            let w = neighbour.vertex1.dot(normal)
            pos.z = (w - normal.x * pos.x - normal.y * pos.y) / normal.z
            //pos.z = neighbour.vertex1.z
        }
        
        assert(seedIndex != -1 || (width == 1 && height == 1 && depth == 1))
        let z = seedIndex != -1 ? seedIndex / (grid.width * grid.height) : self.z
        
        if pos.z < Double(z) {
            pos.z = Double(z)
        } else if pos.z > Double(z + 1) {
            pos.z = Double(z + 1)
        }
        
        assert(bounds.containsPoint(pos))
        return pos
    }
    
    func interpolatePositionYZ(from neighbour: Cuboid) -> Vector {
        assert(neighbour.x != x || neighbour.y != y || neighbour.z != z)
        assert(neighbour.vertex1 != Vector.zero)
        
        var pos = centre
        
        guard (neighbour.surfaceNormal != Vector.zero) else {
            // No serious interpolation possible, just use the same X
            pos.x = neighbour.vertex1.x
            return pos
        }
                
        //assert(neighbour.x == x)
        
        // Do some linear interpolation of the surface normal
        // But the normal is as though it's pointing in the z axis - so just use the z coordinate as the x coordinate
        // Equation is plane.normal.z * x + plane.normal.y * y + plane.normal.x * z = plane.w
        
        let normal = neighbour.surfaceNormal
        let w = neighbour.vertex1.dot(normal)
        pos.x = (w - normal.y * pos.y - normal.z * pos.z) / normal.x
        
        if pos.x < Double(x) {
            pos.x = Double(x)
        } else if pos.x > Double(x + width) {
            pos.x = Double(x + width)
        }

        assert(bounds.containsPoint(pos))
        return pos
    }
    
    func findNeighboursXY(grid: VoxelGrid, index: Int, faces: Int) -> [Cuboid?] {
        // Find the grid of 9 neighbouring cells
        var neighbours = [Cuboid?](repeating: nil, count: 9)
        
        if (faces & (1 << 1) > 0) && x + 1 < grid.width {
            // X+1
            neighbours[5] = grid.findCuboid(at: index + 1)
            
            if neighbours[5] != nil {
                // See if there's also something right and up
                neighbours[8] = y + 1 < grid.height ? grid.findCuboid(at: index + 1 + grid.width) : nil
                
                // See if there's also something right and down
                neighbours[2] = y > 0 ? grid.findCuboid(at: index + 1 - grid.width) : nil
            }
        }
        if (faces & (1 << 3) > 0) && x > 0 {
            // X-1
            neighbours[3] = grid.findCuboid(at: index - 1)
            
            if neighbours[3] != nil {
                // See if there's also something left and up
                neighbours[6] = y + 1 < grid.height ? grid.findCuboid(at: index - 1 + grid.width) : nil
                
                // See if there's also something left and down
                neighbours[0] = y > 0 ? grid.findCuboid(at: index - 1 - grid.width) : nil
            }
        }
        if (faces & (1 << 4) > 0) && x + 1 < grid.width {
            // Y+1
            neighbours[7] = grid.findCuboid(at: index + grid.width)
        }
        if (faces & (1 << 5) > 0) && x > 0 {
            // Y-1
            neighbours[1] = grid.findCuboid(at: index - grid.width)
        }
        return neighbours.map { $0?.axis == .xy ? $0 : nil }
    }
    
    func interpolatePositionXY(neighbours: [Cuboid?], grid: VoxelGrid) -> Vector {
        let neighbourIndices = [1,3,5,7,0,2,6,8].filter({ neighbours[$0] != nil && neighbours[$0]!.vertex1 != Vector.zero && neighbours[$0]!.surfaceNormal != Vector.zero })
        let interpolated = neighbourIndices.map { interpolatePositionXY(from: neighbours[$0]!, grid: grid) }
        if !interpolated.isEmpty {
            return interpolated.reduce(Vector.zero, +) / Double(interpolated.count)
        } else {
            return surfaceCentre(grid: grid)
        }
    }
    
    func interpolatePositionYZ(neighbours: [Cuboid?], grid: VoxelGrid) -> Vector {
        let neighbourIndices = [1,3,5,7,0,2,6,8].filter({ neighbours[$0] != nil && neighbours[$0]!.vertex1 != Vector.zero && neighbours[$0]!.surfaceNormal != Vector.zero })
        let interpolated = neighbourIndices.map { interpolatePositionYZ(from: neighbours[$0]!) }
        if !interpolated.isEmpty {
            return interpolated.reduce(Vector.zero, +) / Double(interpolated.count)
        } else {
            return surfaceCentre(grid: grid)
        }
    }
    
    func findNeighboursYZ(grid: VoxelGrid, index: Int, faces: Int) -> [Cuboid?] {
        // Find the grid of 9 neighbouring cells
        var neighbours = [Cuboid?](repeating: nil, count: 9)
        
        let layerOffset = grid.width * grid.height
        
        if (faces & (1 << 0) > 0) && z + 1 < grid.depth {
            // Z+1
            neighbours[5] = grid.findCuboid(at: index + layerOffset)
                
            if neighbours[5] != nil {
                // See if there's also something forwards and up
                neighbours[8] = y + 1 < grid.height ? grid.findCuboid(at: index + layerOffset + grid.width) : nil
                
                // See if there's also something forwards and down
                neighbours[2] = y > 0 ? grid.findCuboid(at: index + layerOffset - grid.width) : nil
            }
        }
        if (faces & (1 << 2) > 0) && z > 0 {
            // Z-1
            neighbours[3] = grid.findCuboid(at: index - layerOffset)
                
            if neighbours[3] != nil {
                // See if there's also something backwards and up
                neighbours[6] = y + 1 < grid.height ? grid.findCuboid(at: index - layerOffset + grid.width) : nil
                
                // See if there's also something backwards and down
                neighbours[0] = y > 0 ? grid.findCuboid(at: index - layerOffset - grid.width) : nil
            }
        }
        if (faces & (1 << 4) > 0) && x + 1 < grid.width {
            // Y+1
            neighbours[7] = grid.findCuboid(at: index + grid.width)
        }
        if (faces & (1 << 5) > 0) && x > 0 {
            // Y-1
            neighbours[1] = grid.findCuboid(at: index - grid.width)
        }        
        return neighbours.map { $0?.axis == .yz ? $0 : nil }
    }
}

extension Cuboid {
    init(grid: VoxelGrid, index: Int, width: Int, height: Int, depth: Int) {
        let (x, y, z) = grid.positionFromIndex(index)        
        self.init(x: x, y: y, z: z, width: width, height: height, depth: depth)
    }
}
