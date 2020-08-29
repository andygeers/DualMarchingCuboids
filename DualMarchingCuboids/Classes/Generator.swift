//
//  Generator.swift
//  Voxel generator
//
//  Created by Andy Geers on 31/12/2019.
//  Copyright © 2019 Andy Geers. All rights reserved.
//

import Foundation
import Euclid
import ModelIO
import SceneKit

public class Generator {
    
    internal static let HOLE_DEPTH = -1000.0
    internal static let HOLE_OFFSET = -2.0
    
    public let modelHeight : Double
    public let baseHeight : Double
    let texture : VoxelTexture
    
    public init(texture : VoxelTexture, modelHeight : Double = 3.5, baseHeight : Double = 4.0) {
        self.texture = texture
        self.modelHeight = modelHeight
        self.baseHeight = baseHeight
    }
    
    private func isTransparent(x: Int, y: Int, alphaMap: [[Double]]) -> Bool {
        return (x < 0) || (y < 0) || (x >= alphaMap.count - 1) || (y >= alphaMap[0].count - 1) || (alphaMap[x][y] == 0.0) && (alphaMap[x+1][y] == 0.0) && (alphaMap[x+1][y+1] == 0.0) && (alphaMap[x][y+1] == 0.0)
    }
    
    public func generateSurface(on slice: Slice) {
                
        let iterator = slice.iterator(range1: 1 ..< texture.width, yRange: 1 ..< texture.height)
        
        var bounds = VoxelBoundingBox(min: VoxelCoordinates.max, max: VoxelCoordinates.zero, axis: slice.axisMask)
        
        //let maxDepth = self.baseHeight + self.modelHeight
                
        for (x, y, z, j, i, index) in iterator {
            
            if (!self.isTransparent(x: j, y: i, alphaMap: texture.alphaMap)) {
                let depth = outputHeight(texture.heightMap[j][i])
                let intDepth = Int(depth)
                
                bounds.merge(VoxelCoordinates(x: x, y: y, z: z), depth: intDepth)
                
                let distanceFromSurface = Int((depth - Double(intDepth)) * 255)
                var value = 1
                                
                var seed : Cuboid
                if (slice.axisMask == .xy) {
                    let topZ = z + (intDepth - 1)
                    let vertexPosition = Vector(Double(x) + 0.5, Double(y) + 0.5, Double(z) + depth)
                    seed = Cuboid(x: x, y: y, z: topZ, width: 1, height: 1, depth: 1, vertex1: vertexPosition)
                } else if (slice.axisMask == .yz) {
                    let topX = x + (intDepth - 1)
                    let vertexPosition = Vector(Double(x) + depth, Double(y) + 0.5, Double(z) + 0.5)
                    seed = Cuboid(x: topX, y: y, z: z, width: 1, height: 1, depth: 1, vertex1: vertexPosition)
                } else {
                    assert(false)
                    return
                }
                
                var zz = intDepth
                for k in slice.perpendicularIndices(range: (0 ..< intDepth)).reversed() {
                    zz -= 1
                    
                    guard index + k < slice.grid.data.count else { continue }
                    
                    // See if this cell is vacant or not
                    let fillValue : Int
                    
                    let existingData = slice.grid.data[index + k]
                    let isOccupied = existingData > 0
                    
                    if (isOccupied) {
                        slice.grid.addSeed(seed)
                        
                        // There will presumably be an existing seed cuboid that covers this cell
                        // To find it we'll need to track the axis backwards
                        if (existingData & 0x3 == VoxelAxis.xy.rawValue) {
                            var otherIndex = index + k
                            while (true) {
                                if let otherCuboid = slice.grid.cuboids[otherIndex] {
                                    // Split this other cuboid
                                    
                                }
                            }
                        } else if (existingData & 0x3 == VoxelAxis.yz.rawValue) {
                            
                        } else {
                            // Should be a cube here already, nothing further needs doing
                            let existingCube = slice.grid.cuboids[index + k]
                            assert(existingCube != nil && existingCube!.isUnitCube)
                        }
                        
                        if (slice.axisMask == .xy) {
                            let vertexPosition = Vector(Double(x) + 0.5, Double(y) + 0.5, Double(z + zz) + 0.5)
                            seed = Cuboid(x: x, y: y, z: z + zz, width: 1, height: 1, depth: 1, vertex1: vertexPosition)
                        } else if (slice.axisMask == .yz) {
                            let vertexPosition = Vector(Double(x + zz) + 0.5, Double(y) + 0.5, Double(z) + 0.5)
                            seed = Cuboid(x: x + zz, y: y, z: z, width: 1, height: 1, depth: 1, vertex1: vertexPosition)
                        }
                    } else {
                        if (slice.axisMask == .xy) {
                            seed.z -= 1
                            seed.depth += 1
                        } else if (slice.axisMask == .yz) {
                            seed.x -= 1
                            seed.width += 1
                        }
                    }
                    
                    if (j == 0 || k == 0) {
                        // Leave a gap down the left edge and back so that we have a sign change
                        fillValue = 0
                    } else if (!isOccupied) {
                        // There are 255 potential depths at the surface,
                        // so that gives us our depth resolution
                        fillValue = value + distanceFromSurface
                    } else {
                        // Mixed areas should just be treated as max height
                        fillValue = 255
                    }
                    
                    // Voxel data should be 1 at the surface and count up towards the back
                    slice.grid.data[index + k] = slice.grid.data[index + k] | (fillValue << VoxelGrid.dataBits) | slice.axisMask.rawValue
                    value += 255
                }
                
                slice.grid.addSeed(seed)
            }
        }
        
        NSLog("New bounds: %@ to %@", String(describing: bounds.min), String(describing: bounds.max))                
    }        
    
    private func outputHeight(_ height : Double) -> Double {
        if (height == Generator.HOLE_DEPTH) {
            return 0.0
        } else {
            return self.baseHeight + height * self.modelHeight
        }
    }
}
