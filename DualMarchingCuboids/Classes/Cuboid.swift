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
    
    var marchingCubesCase : Int = -1
    
    // There can be up to four discreet surfaces
    // in the most complex Marching Cubes case
    var vertex1 : Vector = Vector.zero
    var vertex2 : Vector = Vector.zero
    var vertex3 : Vector = Vector.zero
    var vertex4 : Vector = Vector.zero
    
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
    
    func triangulate(grid: VoxelGrid, polygons: inout [Euclid.Polygon]) {
        
        let leftCuboid = leftNodeIndex >= 0 ? grid.cuboids[leftNodeIndex] : nil
        let rightCuboid = rightNodeIndex >= 0 ? grid.cuboids[rightNodeIndex] : nil
        let upCuboid = upNodeIndex >= 0 ? grid.cuboids[upNodeIndex] : nil
        let downCuboid = downNodeIndex >= 0 ? grid.cuboids[downNodeIndex] : nil
        let forwardsCuboid = forwardsNodeIndex >= 0 ? grid.cuboids[forwardsNodeIndex] : nil
        let backwardsCuboid = backwardsNodeIndex >= 0 ? grid.cuboids[backwardsNodeIndex] : nil
        
        var polyPoints : [[Vector]] = []
        
        let edges = MarchingCubes.edgeTable[marchingCubesCase]
        
        let solid = marchingCubesCase & (1 << 0) > 0 // f(x, y, z + 0)
        let solidX1 = marchingCubesCase & (1 << 3) > 0 // f(x + 1, y, z) > 0
        let solidY1 = marchingCubesCase & (1 << 4) > 0 // f(x, y + 1, z) > 0
        let solidZ1 = marchingCubesCase & (1 << 1) > 0 // f(x, y, z + 1)
    
        
                
        if let rightCuboid = rightCuboid {
            if edges & (1 << 6) > 0, let upCuboid = upCuboid {
                let swap = marchingCubesCase & (1 << 6) > 0 // or 7?
                
                // Triangle me, up and right: XY
                polyPoints.append([vertex1, rightCuboid.vertex1, upCuboid.vertex1].reversedIf(swap))
            }
        
            if edges & (1 << 10) > 0, let forwardsCuboid = forwardsCuboid {
                let swap = marchingCubesCase & (1 << 6) > 0 // or 2?
                
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
                let swap = marchingCubesCase & (1 << 6) > 0
                
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
            if let polygon = Polygon(points.map({ Vertex($0, plane?.normal ?? Vector.zero) })) {
                polygons.append(polygon)
            }
        }
    }
}
