//
//  Triangulation.swift
//  DualMarchingCuboids
//
//  Created by Andy Geers on 17/09/2020.
//

import Foundation
import Euclid

extension Cuboid {
    func findRightCuboid(grid: VoxelGrid, forForwards: Bool = false) -> Cuboid? {
        // Find the right neighbour nearest the front
        let x = self.x + self.width
        let y = forForwards ? self.y : self.y + self.height - 1
        let z = self.z + self.depth - 1
        let index = grid.cellIndex(x: x, y: y, z: z)
        return grid.findCuboid(at: index)
    }
    
    func findUpCuboid(grid: VoxelGrid, forForwards: Bool = false) -> Cuboid? {
        // Find the up neighbour nearest the front
        let x = forForwards ? self.x : self.x + self.width - 1
        let y = self.y + self.height
        let z = self.z + self.depth - 1
        let index = grid.cellIndex(x: x, y: y, z: z)
        return grid.findCuboid(at: index)
    }
    
    func findLeftCuboid(grid: VoxelGrid, forBackwards: Bool = false) -> Cuboid? {
        // Find the left neighbour nearest the back
        let y = forBackwards ? self.y + self.height - 1 : self.y
        let z = forBackwards ? self.z : self.z + self.depth - 1
        let index = grid.cellIndex(x: x - 1, y: y, z: z)
        return grid.findCuboid(at: index)
    }
    
    func findForwardsCuboid(grid: VoxelGrid, forUp: Bool = false) -> Cuboid? {
        // Find the forwards neighbour nearest the right
        let y = forUp ? self.y + self.height - 1 : self.y
        let index = grid.cellIndex(x: self.x + self.width - 1, y: y, z: self.z + self.depth)
        return grid.findCuboid(at: index)
    }
    
    func findBackwardsCuboid(grid: VoxelGrid, forDown: Bool = false) -> Cuboid? {
        // Find the backwards neighbour nearest the left
        let y = forDown ? self.y : self.y + self.height - 1
        let index = grid.cellIndex(x: self.x, y: y, z: self.z - 1)
        return grid.findCuboid(at: index)
    }
    
    func findDownCuboid(grid: VoxelGrid, forBackwards: Bool = false) -> Cuboid? {
        // Find the down neighbour nearest the back
        let x = self.x
        let z = forBackwards ? self.z : self.z + self.depth - 1
        let index = grid.cellIndex(x: x, y: y - 1, z: z)
        return grid.findCuboid(at: index)
    }
    
    func triangulate(grid: VoxelGrid, polygons: inout [Euclid.Polygon], material: Euclid.Polygon.Material) {
        guard marchingCubesCase >= 0 else { return }
        
        var polyPoints : [([Vector], Polygon.Material)] = []
        
        let edges = MarchingCubes.edgeTable[marchingCubesCase]
        
        let solidXYZ = marchingCubesCase & (1 << 6) > 0 // f(x + 1, y + 1, z + 1)
                
        if let rightCuboid = findRightCuboid(grid: grid) {
            if edges & (1 << 6) > 0, let upCuboid = findUpCuboid(grid: grid) {
                let swap = solidXYZ
                
                // Triangle me, up and right: XY
                polyPoints.append(([vertex1, rightCuboid.vertex1, upCuboid.vertex1].reversedIf(swap), material))
            }
        }
        
        if edges & (1 << 10) > 0, let forwardsCuboid = findForwardsCuboid(grid: grid), let rightCuboid = findRightCuboid(grid: grid, forForwards: true) {
            let swap = solidXYZ
            
            // Triangle me, forwards and right: XZ
            polyPoints.append(([vertex1, forwardsCuboid.vertex1, rightCuboid.vertex1].reversedIf(swap), material))
        }
        
        if let leftCuboid = findLeftCuboid(grid: grid) {
            let swap = marchingCubesCase & (1 << 1) > 0
            
            if edges & (1 << 0) > 0, let downCuboid = findDownCuboid(grid: grid) {
                // Triangle me, down and left: XY
                polyPoints.append(([downCuboid.vertex1, vertex1, leftCuboid.vertex1].reversedIf(swap), material))
            }
        }
        
        if edges & (1 << 8) > 0, let backwardsCuboid = findBackwardsCuboid(grid: grid), let leftCuboid = findLeftCuboid(grid: grid, forBackwards: true) {
            let swap = marchingCubesCase & (1 << 4) > 0
            
            // Triangle me, left and backwards: XZ
            polyPoints.append(([vertex1, backwardsCuboid.vertex1, leftCuboid.vertex1].reversedIf(swap), material))
        }
                
        if edges & (1 << 5) > 0, let upCuboid = findUpCuboid(grid: grid, forForwards: true), let forwardsCuboid = findForwardsCuboid(grid: grid, forUp: true) {
            let swap = solidXYZ
            
            // Triangle me, up and forwards: YZ
            polyPoints.append(([vertex1, upCuboid.vertex1, forwardsCuboid.vertex1].reversedIf(swap), material))
        }
        
        if edges & (1 << 3) > 0, let downCuboid = findDownCuboid(grid: grid, forBackwards: true), let backwardsCuboid = findBackwardsCuboid(grid: grid, forDown: true) {
            let swap = marchingCubesCase & (1 << 3) > 0
            
            // Triangle me, down and backwards: YZ
            polyPoints.append(([downCuboid.vertex1, backwardsCuboid.vertex1, vertex1].reversedIf(swap), material))
        }
        
        for (points, material) in polyPoints {
            let plane = Plane(points: points)
            if let polygon = Polygon(points.map({ Vertex($0, plane?.normal ?? Vector.zero) }), material: material) {
                polygons.append(polygon)
            }
        }
    }
}
