//
//  Slice.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 24/07/2020.
//

import Foundation

public class Slice {
    private let offset : Int
    private let contourTracer : ContourTracer
    public let depthCounts : [Int]
    
    public init?(contourTracer: ContourTracer, z: Int, previousSlice: Slice?) {
        guard z >= -1 && z <= contourTracer.G_DataDepth else { return nil }
        guard z == 0 || z == contourTracer.G_DataDepth - 1 || previousSlice != nil else { return nil }
            
        self.contourTracer = contourTracer
        
        if (z == -1 || z == contourTracer.G_DataDepth) {
            self.offset = -1
        } else {
            self.offset = z * (contourTracer.G_DataWidth * contourTracer.G_DataHeight)
        }
        
        depthCounts = Slice.calculateUpdatedDepthCounts(contourTracer: contourTracer, offset: offset, previousSlice: previousSlice)
    }
    
    private static func calculateUpdatedDepthCounts(contourTracer: ContourTracer, offset: Int, previousSlice: Slice?) -> [Int] {
        
        var depths = [Int](repeating: 0, count: contourTracer.G_DataWidth * contourTracer.G_DataHeight)
        
        var k = 0
        for _ in 0 ..< contourTracer.G_DataHeight { // y
            for _ in 0 ..< contourTracer.G_DataWidth { // x
                let filled = offset >= 0 ? (Double(contourTracer.G_data1[k + offset]) > ContourTracer.G_Threshold) : false
                if let lastSlice = previousSlice {
                    let lastDepth = lastSlice.depthCounts[k]
                    if (filled) {
                        if (lastDepth > 0) {
                            depths[k] = lastDepth + 1
                        } else {
                            depths[k] = 1
                        }
                    } else {
                        if (lastDepth < 0) {
                            depths[k] = lastDepth - 1
                        } else if (lastDepth > 0) {
                            depths[k] = -1
                        }
                    }
                } else {
                    if (filled) {
                        depths[k] = 1
                    }
                }
                
                k += 1
            }
        }
        return depths
    }
}
