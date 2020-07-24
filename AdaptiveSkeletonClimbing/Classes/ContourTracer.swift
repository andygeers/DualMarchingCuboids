//
//  AdaptiveSkeletonClimber.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 08/07/2020.
//

import Euclid

public class ContourTracer {

    static let G_Threshold = 50.0
    
    public let G_data1 : [CUnsignedChar]
    public let G_DataWidth : Int
    public let G_DataHeight : Int
    public let G_DataDepth : Int
    
    public init(G_data1 : [CUnsignedChar], G_DataWidth : Int, G_DataHeight : Int, G_DataDepth : Int) {
        self.G_data1 = G_data1
        self.G_DataWidth = G_DataWidth
        self.G_DataHeight = G_DataHeight
        self.G_DataDepth = G_DataDepth
    }
    
    public func climb() -> Mesh {
        var triangles : [Euclid.Polygon] = []
                
        return Mesh(triangles)
    }
}
