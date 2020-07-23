//
//  VoxelData.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 22/07/2020.
//

import Foundation

enum DataVariability : CChar {
    case x = 0
    case y = 1
    case z = 2
    case outOfBounds = 3
}

internal struct VoxelData {
 
    let climber : AdaptiveSkeletonClimber   // pointer to the data array
    var offX : Int = 0
    var offY : Int = 0
    var offZ : Int = 0
    
    // index of fixed x, index of fixed y
    var fixedx : Int = 0
    var fixedy : Int = 0
    var fixedz : Int = 0
    
    var offset : Int = 0
    var multiplier : Int = 1 // a precomputed variables for fast addressing
    var vary : DataVariability = .outOfBounds
    
    /// INPUT PARAMETERS:
    /// 1) info    pointer to the 1 D array holding data 0 or 1
    /// 2) x       coordinate x of the data line if x>=0, if x<0, dim x is variable
    /// 3) y       coordinate y of the data line if y>=0, if y<0, dim y is variable
    /// 4) z       coordinate z of the data line if z>=0, if z<0, dim z is variable
    /// one of x or y or z must be <0
    /// 5) offx    offset add to coordinate x, ie. true x coordinate = x+offx
    /// 6) offy    offset add to coordinate y. ie. true y coordinate = y+offy
    /// 7) offz    offset add to coordinate z, ie. true z coordinate = z+offz
    /// 8) datadimx   Real dimension of the data grid holding in the
    /// 9) datadimy   1D memory array. That is datadimx*datadimy*datadimz is
    /// 10)datadimz   the size of the 1D array.
    internal init(climber : AdaptiveSkeletonClimber) {
        
        self.climber = climber
    }
    
    init(climber : AdaptiveSkeletonClimber, x : Int, y : Int, z : Int, offx : Int, offy : Int, offz : Int) {
        
        self.init(climber: climber)
        
        reinit(x: x, y: y, z: z, offx: offx, offy: offy, offz: offz)
    }
    
    internal mutating func reinit(x : Int, y : Int, z : Int, offx : Int, offy : Int, offz : Int) {
    
        assert(!((x < 0 && x != -1) || (y < 0 && y != -1) || (z < 0 && z != -1)
            || offx < 0 || offy < 0 || offz < 0), "[Data::ReInit]: invalid input value\n")
        
        self.offX = offx
        self.offY = offy
        self.offZ = offz
        self.fixedx = x + offx
        self.fixedy = y + offy
        self.fixedz = z + offz
        guard fixedx < climber.G_DataWidth, fixedy < climber.G_DataDepth, fixedz < climber.G_DataHeight else {
            // allow out of bound access, but always return 0
            self.vary = .outOfBounds
            self.multiplier = 1
            self.offset = 0
            return
        }
        if (x < 0) {
            offset = fixedz * climber.G_DataWidth * climber.G_DataDepth + fixedy * climber.G_DataWidth + offx
            multiplier = -1 // since not used;
            self.vary = .x
        } else if (y < 0) {
            offset = fixedz * climber.G_DataWidth * climber.G_DataDepth + offy * climber.G_DataWidth + fixedx
            multiplier = -1 // since not used
            vary = .y
        } else if (z < 0) {
            offset = offz * climber.G_DataWidth * climber.G_DataDepth + fixedy * climber.G_DataWidth + fixedx
            multiplier = climber.G_DataWidth * climber.G_DataDepth
            vary = .z
        } else {
            // allow out of bound access, but always return 0
            self.vary = .outOfBounds
            self.multiplier = 1
            self.offset = 0
        }
    }


    // The reason to allow the out of bound access, is that
    // not all data has a dimension which is exactly power of N
    func value(_ i : Int) -> CUnsignedChar {
        switch(vary) {
        case .x:
            if (i + offX < climber.G_DataWidth) {
                // within bound
                return climber.G_data1[offset + i]
            } else {
                return 0
            }

        case .y:
            if (i + offY < climber.G_DataDepth) {
                // within bound
                return climber.G_data1[offset + i * climber.G_DataWidth]
            } else {
                return 0
            }

        case .z:
            if (i + offZ < climber.G_DataHeight) {
                // within bound
                return climber.G_data1[offset + i * multiplier]
            } else {
                return 0
            }

        case .outOfBounds:
            return 0;
        
        }
    }

    subscript(index: Int) -> CChar {
        get {
            return Double(value(index)) >= AdaptiveSkeletonClimber.G_Threshold ? 1 : 0
        }
    }
    
}
