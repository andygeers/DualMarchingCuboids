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
        guard z >= 0 && z < contourTracer.G_DataDepth else { return nil }
        guard z == 0 || previousSlice != nil else { return nil }
            
        self.contourTracer = contourTracer
        self.offset = z * (contourTracer.G_DataWidth * contourTracer.G_DataHeight)
        
        depthCounts = Slice.calculateUpdatedDepthCounts(contourTracer: contourTracer, offset: offset, previousSlice: previousSlice)
    }
    
    private static func calculateUpdatedDepthCounts(contourTracer: ContourTracer, offset: Int, previousSlice: Slice?) -> [Int] {
        
        var depths = [Int](repeating: 0, count: contourTracer.G_DataWidth * contourTracer.G_DataHeight)
        
        var k = 0
        for _ in 0 ..< contourTracer.G_DataHeight { // y
            for _ in 0 ..< contourTracer.G_DataWidth { // x
                let filled = (Double(contourTracer.G_data1[k + offset]) > ContourTracer.G_Threshold)
                if let lastSlice = previousSlice {
                    if (filled) {
                        if (lastSlice.depthCounts[k] > 0) {
                            depths[k] = lastSlice.depthCounts[k] + 1
                        } else {
                            depths[k] = 1
                        }
                    } else {
                        if (lastSlice.depthCounts[k] <= 0) {
                            depths[k] = lastSlice.depthCounts[k] - 1
                        } else {
                            depths[k] = 0
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
        return []
    }
}
