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
    
    public func generateSurface(in grid: VoxelGrid) {
                
        let iterator = XYIterator(grid: grid, xRange: 0 ..< texture.width - 1, yRange: 0 ..< texture.height - 1, z: 0)
        
        for (j, i, _, index) in iterator {
                                
            if (!self.isTransparent(x: j, y: i, alphaMap: texture.alphaMap)) {
                                
                let depth = Int(outputHeight(texture.heightMap[j][i]))
                
                var value = 1
                for k in perpendicularIndices(grid: grid, range: (0 ..< depth)) {
                    // Voxel data should be 1 at the surface and count up towards the back
                    grid.data[index + k] = value
                    value += 1
                }
            }
        }
    }
    
    private func perpendicularIndices(grid: VoxelGrid, range: Range<Int>) -> [Int] {
        return ZIterator(grid: grid, x: 0, y: 0, zRange: range).map { $0.3 }.reversed()
    }
    
    private func outputHeight(_ height : Double) -> Double {
        if (height == Generator.HOLE_DEPTH) {
            return 0.0
        } else {
            return self.baseHeight + height * self.modelHeight
        }
    }
}
