//
//  Interpolation.swift
//  DualMarchingCuboids
//
//  Created by Andy Geers on 17/09/2020.
//

import Foundation
import Euclid

extension Cuboid {
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
