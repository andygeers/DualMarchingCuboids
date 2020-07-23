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
    
    var image : UIImage?
    
    let HOLE_DEPTH = -1000.0
    let HOLE_OFFSET = -2.0
    
    let modelHeight : Double = 3.5
    let baseHeight : Double = 4.0
    
    public func processImage(image: UIImage) throws -> ([CUnsignedChar], Int, Int, Int) {
        self.image = image
        return generateVoxels()
    }
    
    private func generateVoxels() -> ([CUnsignedChar], Int, Int, Int) {
        guard let image = self.image else { return ([], 0, 0, 0) }
        
        let imageSize = image.size
        let imageRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)

        // Create a context to hold the image data
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)

        guard let ctx = CGContext(data: nil,
                            width: Int(imageSize.width),
                            height: Int(imageSize.height),
                            bitsPerComponent: 8,
                            bytesPerRow: 0,
                            space: colorSpace!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return ([], 0, 0, 0) }

        ctx.draw(image.cgImage!, in: imageRect)
        
        // Calculate the histogram
        return self.generateVoxelsFromBitmap(ctx)
    }
    
    private func generateHeightAndAlphaMap(from bitmap : CGContext) -> ([[Double]], [[Double]]) {
        
        var heightMap = Array(repeating: Array(repeating: 0.0, count: (bitmap.height)), count: bitmap.width)
        var alphaMap = Array(repeating: Array(repeating: 0.0, count: (bitmap.height)), count: bitmap.width)
        
        var pixel = bitmap.data!
        
        for y in 0 ..< bitmap.height {
            for x in 0 ..< bitmap.width {
                let rgba = pixel.load(as: UInt32.self)
                let red   = (rgba & 0x000000ff) >> 0
                let green = (rgba & 0x0000ff00) >> 8
                let blue  = (rgba & 0x00ff0000) >> 16
                var alpha = (rgba & 0xff000000) >> 24
                
                var height = 0.0
                
                // Treat bright pink as a special case
                if ((red != 255) || (green != 0) || (blue != 255)) {
                    if (alpha > 0) {
                        // Convert to HSV to get the height
                        let r = Double(red) / 255.0
                        let g = Double(green) / 255.0
                        let b = Double(blue) / 255.0
                        let v = max(r, g, b)
                        height = v * self.modelHeight
                    }
                } else {
                    // Special case
                    height = HOLE_DEPTH
                    alpha = 0
                }
                
                heightMap[x][y] = height
                alphaMap[x][y] = Double(alpha) / 255.0
                
                pixel += 4
            }
                        
            // Sometimes there is padding beyond the edge of the image that we need to skip past
            pixel += bitmap.bytesPerRow - bitmap.width * 4
        }
        
        return (heightMap, alphaMap)
    }
    
    private func isTransparent(x: Int, y: Int, alphaMap: [[Double]]) -> Bool {
        return (x < 0) || (y < 0) || (x >= alphaMap.count - 1) || (y >= alphaMap[0].count - 1) || (alphaMap[x][y] == 0.0) && (alphaMap[x+1][y] == 0.0) && (alphaMap[x+1][y+1] == 0.0) && (alphaMap[x][y+1] == 0.0)
    }
    
    private func surfaceFrom(heightMap: [[Double]], alphaMap: [[Double]]) -> ([CUnsignedChar], Int, Int, Int) {
        
        let height = heightMap.first!.count
        let width = heightMap.count
        let maxDepth = modelHeight + baseHeight
        let voxelDepth = Int(ceil(maxDepth))
        
        var voxels = [CUnsignedChar](repeating: 0, count: width * height * voxelDepth)
        
        for i in 0 ..< height - 1 {
        
            for j in 0 ..< width - 1 {
                                
                if (!self.isTransparent(x: j, y: i, alphaMap: alphaMap)) {
                                    
                    let depth = outputHeight(heightMap[j][i])
                    let midPoint = Float(depth / 2)
                    
                    for k in 0 ... Int(depth) {
                        // w should be 50 at the surface and increase in magnitude towards the middle
                        let w = 50.0 + (midPoint - abs(Float(k) - midPoint))
                        let index = j + i * width + k * (width * height)
                        voxels[index] = CUnsignedChar(w)
                    }
                
                }
            }
        }
        
        return (voxels, width, height, voxelDepth)
    }
    
    private func generateVoxelsFromBitmap(_ bitmap : CGContext) -> ([CUnsignedChar], Int, Int, Int) {
        NSLog("Bitmap dimensions: %d x %d (%d)", bitmap.width, bitmap.height, bitmap.bytesPerRow)
                
        let (heightMap, alphaMap) = generateHeightAndAlphaMap(from: bitmap)
        
        return surfaceFrom(heightMap: heightMap, alphaMap: alphaMap)
        
    }
    
    private func outputHeight(_ height : Double) -> Double {
        if (height == HOLE_DEPTH) {
            return 0.0
        } else {
            return self.baseHeight + height
        }
    }
}
