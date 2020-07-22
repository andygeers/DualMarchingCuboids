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
 
    var content : [CUnsignedChar]   // pointer to the data array
    let width : Int  // along x axis
    let depth : Int  // along y axis
    let height : Int // along z axis
    let offX : Int
    let offY : Int
    let offZ : Int
    
    // index of fixed x, index of fixed y
    let fixedx : Int
    let fixedy : Int
    let fixedz : Int
    
    let offset : Int
    let multiplier : Int // a precomputed variables for fast addressing
    let vary : DataVariability
    
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
    internal init(info : [CUnsignedChar], x : Int, y : Int, z : Int,
                  offx : Int, offy : Int, offz : Int,
                  datadimx : Int, datadimy : Int, datadimz : Int) {
    
        assert(!((x < 0 && x != -1) || (y < 0 && y != -1) || (z < 0 && z != -1)
            || offx < 0 || offy < 0 || offz < 0), "[Data::ReInit]: invalid input value\n")
        
        content = info
        self.offX = offx
        self.offY = offy
        self.offZ = offz
        self.width = datadimx
        self.depth = datadimy
        self.height = datadimz
        self.fixedx = x + offx
        self.fixedy = y + offy
        self.fixedz = z + offz
        guard (fixedx < datadimx && fixedy < datadimy && fixedz < datadimz) else {
            // allow out of bound access, but always return 0
            self.vary = .outOfBounds
            self.multiplier = 1
            self.offset = 0
            return
        }
        if (x < 0) {
            offset = fixedz * width * depth + fixedy * width + offx
            multiplier = -1 // since not used;
            self.vary = .x
        } else if (y < 0) {
            offset = fixedz * width * depth + offy * width + fixedx
            multiplier = -1 // since not used
            vary = .y
        } else if (z < 0) {
            offset = offz * width * depth + fixedy * width + fixedx
            multiplier = width * depth
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
            if (i + offX < width) {
                // within bound
                return content[offset + i]
            } else {
                return 0
            }

        case .y:
            if (i + offY < depth) {
                // within bound
                return content[offset + i * width]
            } else {
                return 0
            }

        case .z:
            if (i + offZ < height) {
                // within bound
                return content[offset + i * multiplier]
            } else {
                return 0
            }

        case .outOfBounds:
            return 0;
        
        }
    }

    subscript(index: Int) -> CChar {
        get {
            return value(index) >= AdaptiveSkeletonClimber.G_Threshold ? 1 : 0
        }
    }
    
}
