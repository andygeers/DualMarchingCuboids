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
    
    var isUnitCube : Bool {
        return width == 1 && height == 1 && depth == 1
    }
    
    var marchingCubesCase : Int = -1
    
    // There can be up to four discreet surfaces
    // in the most complex Marching Cubes case
    var vertex1 : Vector = Vector.zero
    var vertex2 : Vector = Vector.zero
    var vertex3 : Vector = Vector.zero
    var vertex4 : Vector = Vector.zero
    
    var surfaceNormal : Vector = Vector.zero
    
    mutating func appendVertex(_ vertex: Vector) {
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
    
    var bounds : Bounds {
        return Bounds(min: corner, max: corner + cellSize)
    }
    
    func containsIndex(_ index : Int, grid: VoxelGrid) -> Bool {
        let z = index / (grid.width * grid.height)
        let y = (index - z * grid.width * grid.height) / grid.width
        let x = index % grid.width
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
    
    func interpolatePositionXY(from neighbour: Cuboid) -> Vector {
        assert(neighbour.x != x || neighbour.y != y || neighbour.z != z)
        assert(neighbour.vertex1 != Vector.zero)
        
        var pos = centre
        
        guard (neighbour.surfaceNormal != Vector.zero) else {
            // No serious interpolation possible, just use the same Z
            pos.z = neighbour.vertex1.z
            return pos
        }
                
        assert(neighbour.z == z)
        
        // Do some linear interpolation of the surface normal
        // Equation is plane.normal.x * x + plane.normal.y * y + plane.normal.z * z = plane.w
        let w = neighbour.vertex1.dot(neighbour.surfaceNormal)
        pos.z = (w - neighbour.surfaceNormal.x * centre.x - neighbour.surfaceNormal.y * centre.y) / neighbour.surfaceNormal.z
        
        if pos.z < Double(z) {
            pos.z = Double(z)
        } else if pos.z > Double(z + depth) {
            pos.z = Double(z + depth)
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
                
        assert(neighbour.x == x)
        
        // Do some linear interpolation of the surface normal
        // But the normal is as though it's pointing in the z axis - so just use the z coordinate as the x coordinate
        // Equation is plane.normal.z * x + plane.normal.y * y + plane.normal.x * z = plane.w
        
        let w = neighbour.vertex1.x * neighbour.surfaceNormal.z + neighbour.vertex1.y * neighbour.surfaceNormal.y + neighbour.vertex1.z * neighbour.surfaceNormal.x
        pos.x = (w - neighbour.surfaceNormal.z * centre.z - neighbour.surfaceNormal.y * centre.y) / neighbour.surfaceNormal.z
        
        if pos.x < Double(x) {
            pos.x = Double(x)
        } else if pos.x > Double(x + width) {
            pos.x = Double(x + width)
        }

        assert(bounds.containsPoint(pos))
        return pos
    }
    
    func interpolatePositionXY(grid: VoxelGrid, index: Int, faces: Int) -> Vector {
        // Find the grid of 9 neighbouring cells
        var neighbours = [Cuboid?](repeating: nil, count: 9)
        
        if (faces & (1 << 1) > 0) && x + 1 < grid.width {
            // X+1
            neighbours[5] = grid.findCube(at: index + 1)
            
            if neighbours[5] != nil {
                // See if there's also something right and up
                neighbours[8] = y + 1 < grid.height ? grid.findCube(at: index + 1 + grid.width) : nil
                
                // See if there's also something right and down
                neighbours[2] = y > 0 ? grid.findCube(at: index + 1 - grid.width) : nil
            }
        }
        if (faces & (1 << 3) > 0) && x > 0 {
            // X-1
            neighbours[3] = grid.findCube(at: index - 1)
            
            if neighbours[3] != nil {
                // See if there's also something left and up
                neighbours[6] = y + 1 < grid.height ? grid.findCube(at: index - 1 + grid.width) : nil
                
                // See if there's also something left and down
                neighbours[0] = y > 0 ? grid.findCube(at: index - 1 - grid.width) : nil
            }
        }
        if (faces & (1 << 4) > 0) && x + 1 < grid.width {
            // Y+1
            neighbours[7] = grid.findCube(at: index + grid.width)
        }
        if (faces & (1 << 5) > 0) && x > 0 {
            // Y-1
            neighbours[1] = grid.findCube(at: index - grid.width)
        }
        
        let neighbourIndices = [1,3,5,7,0,2,6,8].filter({ neighbours[$0] != nil && neighbours[$0]!.vertex1 != Vector.zero && neighbours[$0]!.surfaceNormal != Vector.zero })
        let interpolated = neighbourIndices.map { interpolatePositionXY(from: neighbours[$0]!) }
        if !interpolated.isEmpty {
            return interpolated.reduce(Vector.zero, +) / Double(interpolated.count)
        } else {
            return centre
        }
    }
    
    func interpolatePositionYZ(grid: VoxelGrid, index: Int, faces: Int) -> Vector {
        // Find the grid of 9 neighbouring cells
        var neighbours = [Cuboid?](repeating: nil, count: 9)
        
        let layerOffset = grid.width * grid.height
        
        if (faces & (1 << 0) > 0) && z + 1 < grid.depth {
            // Z+1
            neighbours[5] = grid.findCube(at: index + layerOffset)
                
            if neighbours[5] != nil {
                // See if there's also something forwards and up
                neighbours[8] = y + 1 < grid.height ? grid.findCube(at: index + layerOffset + grid.width) : nil
                
                // See if there's also something forwards and down
                neighbours[2] = y > 0 ? grid.findCube(at: index + layerOffset - grid.width) : nil
            }
        }
        if (faces & (1 << 2) > 0) && z > 0 {
            // Z-1
            neighbours[3] = grid.findCube(at: index - layerOffset)
                
            if neighbours[3] != nil {
                // See if there's also something backwards and up
                neighbours[6] = y + 1 < grid.height ? grid.findCube(at: index - layerOffset + grid.width) : nil
                
                // See if there's also something backwards and down
                neighbours[0] = y > 0 ? grid.findCube(at: index - layerOffset - grid.width) : nil
            }
        }
        if (faces & (1 << 4) > 0) && x + 1 < grid.width {
            // Y+1
            neighbours[7] = grid.findCube(at: index + grid.width)
        }
        if (faces & (1 << 5) > 0) && x > 0 {
            // Y-1
            neighbours[1] = grid.findCube(at: index - grid.width)
        }
        
        if let neighbourIndex = [1,3,5,7].first(where: { neighbours[$0] != nil && neighbours[$0]!.vertex1 != Vector.zero }) {
            return interpolatePositionYZ(from: neighbours[neighbourIndex]!)
        } else if let neighbourIndex = [0,2,6,8].first(where: { neighbours[$0] != nil && neighbours[$0]!.vertex1 != Vector.zero }) {
            return interpolatePositionYZ(from: neighbours[neighbourIndex]!)
        }
        return centre
    }
    
    func triangulate(grid: VoxelGrid, polygons: inout [Euclid.Polygon], material: Euclid.Polygon.Material) {
        guard marchingCubesCase >= 0 else { return }
        
        let leftCuboid = leftNodeIndex >= 0 ? grid.cuboids[leftNodeIndex] : nil
        let rightCuboid = rightNodeIndex >= 0 ? grid.cuboids[rightNodeIndex] : nil
        let upCuboid = upNodeIndex >= 0 ? grid.cuboids[upNodeIndex] : nil
        let downCuboid = downNodeIndex >= 0 ? grid.cuboids[downNodeIndex] : nil
        let forwardsCuboid = forwardsNodeIndex >= 0 ? grid.cuboids[forwardsNodeIndex] : nil
        let backwardsCuboid = backwardsNodeIndex >= 0 ? grid.cuboids[backwardsNodeIndex] : nil
        
        var polyPoints : [[Vector]] = []
        
        let edges = MarchingCubes.edgeTable[marchingCubesCase]
        
        let solidXYZ = marchingCubesCase & (1 << 6) > 0 // f(x + 1, y + 1, z + 1)
                
        if let rightCuboid = rightCuboid {
            if edges & (1 << 6) > 0, let upCuboid = upCuboid {
                let swap = solidXYZ
                
                // Triangle me, up and right: XY
                polyPoints.append([vertex1, rightCuboid.vertex1, upCuboid.vertex1].reversedIf(swap))
            }
        
            if edges & (1 << 10) > 0, let forwardsCuboid = forwardsCuboid {
                let swap = solidXYZ
                
                // Triangle me, forwards and right: XZ
                polyPoints.append([vertex1, forwardsCuboid.vertex1, rightCuboid.vertex1].reversedIf(swap))
            }
        }
        
        if let leftCuboid = leftCuboid {
            if edges & (1 << 0) > 0, let downCuboid = downCuboid {
                let swap = marchingCubesCase & (1 << 1) > 0
                
                // Triangle me, down and left: XY
                polyPoints.append([downCuboid.vertex1, vertex1, leftCuboid.vertex1].reversedIf(swap))
            }
            if edges & (1 << 8) > 0, let backwardsCuboid = backwardsCuboid {
                let swap = marchingCubesCase & (1 << 4) > 0
                
                // Triangle me, left and backwards: XZ
                polyPoints.append([vertex1, backwardsCuboid.vertex1, leftCuboid.vertex1].reversedIf(swap))
            }
        }
                
        if edges & (1 << 5) > 0, let upCuboid = upCuboid {
            if let forwardsCuboid = forwardsCuboid {
                let swap = solidXYZ
                
                // Triangle me, up and forwards: YZ
                polyPoints.append([vertex1, upCuboid.vertex1, forwardsCuboid.vertex1].reversedIf(swap))
            }
        }
        
        if edges & (1 << 3) > 0, let downCuboid = downCuboid, let backwardsCuboid = backwardsCuboid {
            let swap = marchingCubesCase & (1 << 3) > 0
            
            // Triangle me, down and backwards: YZ
            polyPoints.append([downCuboid.vertex1, backwardsCuboid.vertex1, vertex1].reversedIf(swap))
        }
        
        for points in polyPoints {
            let plane = Plane(points: points)
            if let polygon = Polygon(points.map({ Vertex($0, plane?.normal ?? Vector.zero) }), material: material) {
                polygons.append(polygon)
            }
        }
    }
}
