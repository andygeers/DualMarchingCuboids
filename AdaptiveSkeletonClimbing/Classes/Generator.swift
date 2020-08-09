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
                
        let iterator = slice.iterator(range1: 0 ..< texture.width - 1, yRange: 0 ..< texture.height - 1)
        
        var bounds = VoxelBoundingBox(min: VoxelCoordinates.max, max: VoxelCoordinates.zero, axis: slice.axisMask)
        
        for (x, y, z, j, i, index) in iterator {
            
            if (!self.isTransparent(x: j, y: i, alphaMap: texture.alphaMap)) {
                let depth = Int(outputHeight(texture.heightMap[j][i]))
                
                bounds.merge(VoxelCoordinates(x: x, y: y, z: z), depth: depth)
                
                var value = 1
                for k in slice.perpendicularIndices(range: (0 ..< depth)).reversed() {
                    // Voxel data should be 1 at the surface and count up towards the back
                    slice.grid.data[index + k] = slice.grid.data[index + k] | (value << 2) | slice.axisMask.rawValue
                    value += 1
                }
            }
        }
        
        NSLog("New bounds: %@ to %@", String(describing: bounds.min), String(describing: bounds.max))
        
        // Add a bounding box
        slice.grid.addBoundingBox(bounds)
    }        
    
    private func outputHeight(_ height : Double) -> Double {
        if (height == Generator.HOLE_DEPTH) {
            return 0.0
        } else {
            return self.baseHeight + height * self.modelHeight
        }
    }
}
