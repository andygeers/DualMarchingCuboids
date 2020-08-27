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
                    height = Generator.HOLE_DEPTH
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
}
