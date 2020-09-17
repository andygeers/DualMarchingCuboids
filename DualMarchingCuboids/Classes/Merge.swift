//
//  Merge.swift
//  DualMarchingCuboids
//
//  Created by Andy Geers on 17/09/2020.
//

import Foundation
import Euclid

extension Cuboid {
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
            
            // TODO: In future we might want to merge rather than just ignore
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
