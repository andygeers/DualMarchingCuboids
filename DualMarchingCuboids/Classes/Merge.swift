//
//  Merge.swift
//  DualMarchingCuboids
//
//  Created by Andy Geers on 17/09/2020.
//

import Foundation
import Euclid

extension Cuboid {
    static let DISTORTION_THRESHOLD = 0.2
    
    func canMerge(with other: Cuboid, grid: VoxelGrid) -> Bool {
        if grid.uglyCubes.contains(self.index(grid: grid)) || grid.uglyCubes.contains(other.index(grid: grid)) {
            return false
        }
        
        // Conditions for merging:
        // 1. They are in the same axis and share the same MC case
        let myCase = self.sampleMarchingCubesCaseIfMissing(grid: grid)
        let otherCase = other.sampleMarchingCubesCaseIfMissing(grid: grid)
        guard myCase == otherCase else { return false }
        
        // 2. They are both 'simple' cases
        guard MarchingCubes.surfaceCount[myCase] <= 1 && MarchingCubes.surfaceCount[otherCase] <= 1 else { return false }
        
        // 3. They line up & share same dimensions (except in the direction we are merging)
        guard (self.x == other.x && self.y == other.y && self.width == other.width && self.height == other.height) ||
            (self.x == other.x && self.z == other.z && self.width == other.width && self.depth == other.depth) ||
            (self.y == other.y && self.z == other.z && self.height == other.height && self.depth == other.depth) else { return false }
        
        // 4. Only merge along the surface - keep the Marching Cubes case the same
        guard self.marchingCubesCase == other.marchingCubesCase else { return false }
        
        // 5. Measure what the distortion would be
        guard measureDistortion(neighbour: other) <= Cuboid.DISTORTION_THRESHOLD else {
            return false
        }
        
        // ?6. Max size?
        
        return true
    }
    
    func measureDistortion(neighbour: Cuboid) -> Double {
        // Make a plane based on our position and surface normal
        guard self.surfaceNormal != Vector.zero && self.vertex1 != Vector.zero && neighbour.vertex1 != Vector.zero else { return 0.0 }
        guard let plane = Plane(normal: self.surfaceNormal, pointOnPlane: self.vertex1) else { return 0.0 }
        
        // The distortion is the distance between the neighbour's vertex and this plane
        return abs(neighbour.vertex1.distance(from: plane))
    }
    
    func merge(with other: Cuboid, grid: VoxelGrid) -> Cuboid {
        var result : Cuboid
        if (self.x == other.x + other.width) {
            result = other
            result.width += self.width
        } else if (other.x == self.x + self.width) {
            result = self
            result.width += other.width
        } else if (self.y == other.y + other.height) {
            result = other
            result.height += self.height
        } else if (other.y == self.y + self.height) {
            result = self
            result.height += other.height
        } else if (self.z == other.z + other.depth) {
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
        let normals = [self.surfaceNormal, other.surfaceNormal].filter({ $0 != Vector.zero })
        if (normals.count > 0) {
            result.surfaceNormal = normals.reduce(Vector.zero, +) / Double(normals.count)
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
        (1...2).forEach { _ in
            // Iterate over all the cuboid indices that currently exist
            let indices = cuboids.keys.sorted()
            for index in indices {
                // Look up this cuboid and see if we've merged it already
                guard var cuboid = findCuboid(at: index), cuboid.index(grid: self) == index else { continue }
                
                let directions : [Direction]
                switch (cuboid.axis) {
                case .xy:
                    directions = [.z, .x, .y]
                case .yz:
                    directions = [.x, .z, .y]
                default:
                    directions = [.x, .y, .z]
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
}
