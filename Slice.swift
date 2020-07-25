//
//  Slice.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 24/07/2020.
//

import Foundation
import Euclid

public class Slice {
    private let offset : Int
    private let contourTracer : ContourTracer
    private let previousSlice : Slice?
    public let depthCounts : [Int]
    
    public init?(contourTracer: ContourTracer, z: Int, previousSlice: Slice?) {
        guard z >= -1 && z <= contourTracer.G_DataDepth else { return nil }
        guard z == 0 || z == contourTracer.G_DataDepth - 1 || previousSlice != nil else { return nil }
            
        self.contourTracer = contourTracer
        self.previousSlice = previousSlice
        
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
    
    func generatePolygons(polygons : inout [Euclid.Polygon]) {
        var k = 0
        for y in 0 ..< contourTracer.G_DataHeight {
            for x in 0 ..< contourTracer.G_DataWidth {
                let depth = depthCounts[k]
                
                // See if we're newly filled
                if (depth == 1) {
                    
                    /*
                        1/////2//////3
                        //    //    //
                        //    //    //
                        4/////0//////5
                        //    //    //
                        //    //    //
                        6/////7//////8
                     */
                    // See if any of the other eight vertices are available yet
                    let depths = [
                        depth,
                        x > 0 && y < contourTracer.G_DataHeight ? depthCounts[k - 1 + contourTracer.G_DataWidth] : 0,
                        y < contourTracer.G_DataHeight ? depthCounts[k + contourTracer.G_DataWidth] : 0,
                        x < contourTracer.G_DataWidth && y < contourTracer.G_DataHeight ? depthCounts[k + 1 + contourTracer.G_DataWidth] : 0,
                        x > 0 ? depthCounts[k - 1] : 0,
                        x < contourTracer.G_DataWidth ? depthCounts[k + 1] : 0,
                        x > 0 && y > 0 ? depthCounts[k - 1 - contourTracer.G_DataWidth] : 0,
                        x < contourTracer.G_DataWidth && y > 0 ? depthCounts[k + 1 - contourTracer.G_DataWidth] : 0
                    ]
                    if (depths[2] > 0) {
                        
                        if (depths[4] > 0) {
                            
                        }
                        if (depths[5] > 0) {
                            
                        }
                    }
                    if (depths[7] > 0) {
                        
                        if (depths[4] > 0) {
                            
                        }
                        if (depths[5] > 0) {
                            
                        }
                    }
                    
                }
                
                k += 1
            }
        }
    }
}
