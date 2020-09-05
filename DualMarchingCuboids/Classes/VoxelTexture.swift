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

public class VoxelTexture {
    
    let image : UIImage
    var heightMap : [[Double]] = []
    var alphaMap : [[Double]] = []
    var surfaceNormals : [[Vector]] = []
    
    private let HOLE_DEPTH = -1000.0
    private let HOLE_OFFSET = -2.0
    
    public init(image: UIImage) throws {
        self.image = image
        processImage()
    }
    
    private func processImage() {
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
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }

        ctx.draw(image.cgImage!, in: imageRect)
        
        // Calculate the histogram
        generateHeightAndAlphaMap(from: ctx)
        
        generateSurfaceNormals()
    }
    
    private func generateHeightAndAlphaMap(from bitmap : CGContext) {
        
        NSLog("Bitmap dimensions: %d x %d (%d)", bitmap.width, bitmap.height, bitmap.bytesPerRow)
        
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
                        height = v
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
        
        self.heightMap = heightMap
        self.alphaMap = alphaMap
    }
    
    private func generateSurfaceNormals() {
        let h = height
        let w = width
        surfaceNormals = []
        for x in 0 ..< w {
            var columnNormals = [Vector](repeating: Vector.zero, count: h)
            
            for y in 0 ..< h {
                
                // Sample the heights all around
                var surrounds = [Double](repeating: 0.0, count: 9)
                var k = 0
                for yy in y - 1 ... y + 1 {
                    for xx in x - 1 ... x + 1 {
                        let xx = xx < 0 ? 0 : (xx >= w ? w - 1 : xx)
                        let yy = yy < 0 ? 0 : (yy >= h ? h - 1 : yy)
                        surrounds[k] = outputHeight(heightMap[xx][yy])
                        k += 1
                    }
                }
                
                // Calculate normal
                // From https://stackoverflow.com/a/49640606/4397
                columnNormals[y] = Vector(2.0 * (surrounds[3] - surrounds[5]), 2.0 * (surrounds[1] - surrounds[7]), 4.0).normalized()
            }
            surfaceNormals.append(columnNormals)
        }
    }
    
    public var height : Int {
        get {
            return heightMap.first!.count
        }
    }
    
    public var width : Int {
        get {
            return heightMap.count
        }
    }
    
    func outputHeight(_ height : Double, baseHeight: Double = 1.0, modelHeight: Double = 1.0) -> Double {
        if (height == HOLE_DEPTH) {
            return 0.0
        } else {
            return baseHeight + height * modelHeight
        }
    }
}
