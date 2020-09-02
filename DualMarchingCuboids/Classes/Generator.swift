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
                let depth = texture.outputHeight(texture.heightMap[j][i], baseHeight: baseHeight, modelHeight: modelHeight)
                let normal = texture.surfaceNormals[j][i]
                let intDepth = Int(depth)
                
                bounds.merge(VoxelCoordinates(x: x, y: y, z: z), depth: intDepth)
                
                        
                if (slice.axisMask == .xy) {
                    let topZ = z + (intDepth - 1)
                    let vertexPosition = Vector(Double(x) + 0.5, Double(y) + 0.5, Double(z) + depth)
                    let seed = Cuboid(x: x, y: y, z: topZ, width: 1, height: 1, depth: 1, vertex1: vertexPosition, surfaceNormal: normal)
                    slice.grid.addSeed(seed)
                } else if (slice.axisMask == .yz) {
                    let topX = x + (intDepth - 1)
                    let vertexPosition = Vector(Double(x) + depth, Double(y) + 0.5, Double(z) + 0.5)
                    let seed = Cuboid(x: topX, y: y, z: z, width: 1, height: 1, depth: 1, vertex1: vertexPosition, surfaceNormal: normal)
                    slice.grid.addSeed(seed)
                }
                
                for k in slice.perpendicularIndices(range: (0 ..< intDepth)).reversed() {
                    
                    guard index + k < slice.grid.data.count else { continue }
                    
                    // Voxel data should be 1 at the surface and count up towards the back
                    slice.grid.data[index + k] |= VoxelGrid.occupiedFlag | slice.axisMask.rawValue                    
                }
                
                //slice.grid.addSeed(index)
            }
        }
        
        NSLog("New bounds: %@ to %@", String(describing: bounds.min), String(describing: bounds.max))                
    }                
}
