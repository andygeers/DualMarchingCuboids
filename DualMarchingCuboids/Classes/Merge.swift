//
//  Merge.swift
//  DualMarchingCuboids
//
//  Created by Andy Geers on 17/09/2020.
//

import Foundation
import Euclid

extension Cuboid {
    func canMerge(with other: Cuboid, grid: VoxelGrid) -> Bool {
        // Conditions for merging:
        // 1. They are in the same axis and share the same MC case
        let myCase = self.sampleMarchingCubesCaseIfMissing(grid: grid)
        let otherCase = other.sampleMarchingCubesCaseIfMissing(grid: grid)
        guard myCase == otherCase else { return false }
        
        // 2. They are both 'simple' cases
        guard MarchingCubes.surfaceCount[myCase] <= 1 && MarchingCubes.surfaceCount[otherCase] <= 1 else { return false }
        
        // 3. They line up & share same dimensions (except in the direction we are merging)
        // TODO: Allow merging in other axes too
        guard self.x == other.x && self.y == other.y && self.width == other.width && self.height == other.height else { return false }
                
        // 4. Merging would leave it with the same Marching Cubes case
        if (self.z == other.z + other.depth) {
            let fromOther = otherCase & ((1 << 0) | (1 << 3) | (1 << 4) | (1 << 7))
            let fromSelf = myCase & ((1 << 1) | (1 << 2) | (1 << 5) | (1 << 6))
            let combinedCase = fromSelf | fromOther
            // Test: Is it in fact theoretically impossible for it to change it?
            assert(combinedCase == myCase)
            guard combinedCase == myCase else { return false }
        } else if (other.z == self.z + self.depth) {
            let fromSelf = myCase & ((1 << 0) | (1 << 3) | (1 << 4) | (1 << 7))
            let fromOther = otherCase & ((1 << 1) | (1 << 2) | (1 << 5) | (1 << 6))
            let combinedCase = fromSelf | fromOther
            // Test: Is it in fact theoretically impossible for it to change it?
            assert(combinedCase == myCase)
            guard combinedCase == myCase else { return false }
        } else {
            return false
        }
        
        // ?5. Max size?
        
        return true
    }
    
    func merge(with other: Cuboid, grid: VoxelGrid) -> Cuboid {
        var result : Cuboid
        if (self.z == other.z + other.depth) {
            result = other
            result.depth += self.depth
        } else if (other.z == self.z + self.depth) {
            result = self
            result.depth += other.depth
        } else {
            assert(false)
            result = self
        }
        if (self.vertex1 != Vector.zero) {
            result.vertex1 = self.vertex1
        } else if (other.vertex1 != Vector.zero) {
            result.vertex1 = other.vertex1
        }
        if (self.seedIndex != -1) {
            result.seedIndex = self.seedIndex
        } else if (other.seedIndex != -1) {
            result.seedIndex = other.seedIndex
        }
        
        result.markGridIndices(grid: grid)
        
        return result
    }
    
    func growAlongZAxis(grid: VoxelGrid, neighbours: [Int]) -> Cuboid {
        var cuboid = self
        cuboid.axis = .xy
        
        let cubeIndex = self.marchingCubesCase
        var grownIndex = index(grid: grid)
        var grownNeighbours = neighbours
        
        let nextZ = grid.width * grid.height
        let nextY = grid.width * cuboid.height
        
        while cuboid.z > 0 && cuboid.depth < Generator.maxDepth {
            
            grownNeighbours[0] = grid.data[grownIndex - nextZ]
            grownNeighbours[3] = cuboid.x + cuboid.width < grid.width ? grid.data[grownIndex + cuboid.width - nextZ] : 0
            grownNeighbours[4] = cuboid.y + cuboid.height < grid.height ? grid.data[grownIndex + nextY - nextZ] : 0
            grownNeighbours[7] = cuboid.x + cuboid.width < grid.width && cuboid.y + cuboid.height < grid.height ? grid.data[grownIndex + cuboid.width + nextY - nextZ] : 0
            
            guard (grownNeighbours[0] & VoxelGrid.occupiedFlag > 0) || (grownNeighbours[3] & VoxelGrid.occupiedFlag > 0) || (grownNeighbours[4] & VoxelGrid.occupiedFlag > 0) || (grownNeighbours[7] & VoxelGrid.occupiedFlag > 0) else { break }
            guard grownNeighbours[0] & DualMarchingCuboids.visitedFlag == 0 else { break }
            
            guard grid.findCuboid(at: grownIndex - nextZ) == nil else { break }
            
            let newCubesCase = Cuboid.caseFromNeighbours(grownNeighbours)
            guard newCubesCase == cubeIndex else { break }
            
            if (grownNeighbours[0] & 0x3 == VoxelAxis.xy.rawValue) {
                cuboid.z -= 1
                grownIndex -= nextZ
                cuboid.depth += 1
            } else {
                break
            }
        }
        
        var farZ = grid.width * grid.height * cuboid.depth
        
        while cuboid.z + cuboid.depth + 1 < grid.depth && cuboid.depth < Generator.maxDepth {
            grownNeighbours[1] = grid.data[grownIndex + farZ + nextZ]
            grownNeighbours[2] = cuboid.x + cuboid.width < grid.width ? grid.data[grownIndex + farZ + nextZ + cuboid.width] : 0
            grownNeighbours[5] = cuboid.y + cuboid.height < grid.height ? grid.data[grownIndex + farZ + nextZ + nextY] : 0
            grownNeighbours[6] = cuboid.x + cuboid.width < grid.width && cuboid.y + cuboid.height < grid.height ? grid.data[grownIndex + farZ + nextZ + cuboid.width + nextY] : 0
            
            guard grownNeighbours[1] & DualMarchingCuboids.visitedFlag == 0 else { break }
            
            guard grid.cuboids[farZ + nextZ] == nil else { break }
            
            let newCubesCase = Cuboid.caseFromNeighbours(grownNeighbours)
            guard newCubesCase == cubeIndex else { break }
            
            if (grownNeighbours[1] & VoxelAxis.yz.rawValue == 0) {
                cuboid.depth += 1
                farZ += nextZ
            } else {
                break
            }
        }
        
        return cuboid
    }
}

enum Direction {
    case x
    case y
    case z
}

extension Cuboid {
    func findNeighbour(direction: Direction, grid: VoxelGrid) -> Cuboid? {
        switch direction {
        case .x:
            let x = self.x + width
            let index = grid.cellIndex(x: x, y: self.y, z: self.z)
            return grid.findCuboid(at: index)
        case .y:
            let y = self.y + height
            let index = grid.cellIndex(x: self.x, y: y, z: self.z)
            return grid.findCuboid(at: index)
        case .z:
            let z = self.z + depth
            let index = grid.cellIndex(x: self.x, y: self.y, z: z)
            return grid.findCuboid(at: index)
        }
    }
    
    /// Make all cells within the cuboid point to this index
    func markGridIndices(grid: VoxelGrid) {
        let myIndex = index(grid: grid)
        
        for zz in z ..< z + depth {
            for yy in y ..< y + height {
                for xx in x ..< x + width {
                    if ((xx != 0) || (yy != 0) || (zz != 0)) {
                        let index = grid.cellIndex(x: xx, y: yy, z: zz)
                        grid.cuboids.removeValue(forKey: index)
                        grid.data[index] = (grid.data[index] & VoxelGrid.dataBits) | (myIndex << VoxelGrid.dataBits) | DualMarchingCuboids.visitedFlag
                    }
                }
            }
        }
                
        grid.cuboids[myIndex] = self
    }
}

extension VoxelGrid {
    func mergeCuboids() {
        // Iterate over all the cuboid indices that currently exist
        let indices = cuboids.keys.sorted()
        for index in indices {
            // Look up this cuboid and see if we've merged it already
            guard var cuboid = findCuboid(at: index), cuboid.index(grid: self) == index else { continue }
            
            let directions : [Direction]
            if cuboid.axis == .yz {
                directions = [.x, .z, .y]
            } else {
                directions = [.z, .x, .y]
            }
            
            for direction in directions {
                // Find the neighbouring cube in this direction
                while let neighbour = cuboid.findNeighbour(direction: direction, grid: self), cuboid.canMerge(with: neighbour, grid: self) {
                    cuboid = cuboid.merge(with: neighbour, grid: self)
                }
            }
        }
    }
}