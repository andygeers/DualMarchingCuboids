//
//  Slab.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 21/07/2020.
//

import Foundation

// enumeration of the index of the 4 subsquares.
enum SlabCorner : Int {
    case bottomLeft = 0
    case bottomRight = 1
    case topLeft = 2
    case topRight = 3
}

/// The volume between 2 consecutive parallel farms.
/// Bookkeep the occupant.
class Slab {
    
    private var py : Int
    private var xdike : Int
    private var bitmap = [CUnsignedChar](repeating: 0, count: ((AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N) >> 3) + 1)
    private var isEmpty : Bool   // the slab is empty, no isosurface crossing
    
    public var xlign : [Lign] //[N]
    public var ylign : [Lign] //[N];
    
    internal init(block: Block, farmk : Farm, farmkplus1 : Farm) {
        isEmpty = farmk.emptyQ() && farmkplus1.emptyQ()
        
        xlign.reserveCapacity(AdaptiveSkeletonClimber.N)
        ylign.reserveCapacity(AdaptiveSkeletonClimber.N)
        
        for i in 0 ..< AdaptiveSkeletonClimber.N {
            var nextXlign = Lign(block: block, offset: 0, dimension: .x)
            var nextYlign = Lign(block: block, offset: 0, dimension: .y)
            xlign.append(nextXlign)
            ylign.append(nextYlign)
            
            for j in 0 ..< AdaptiveSkeletonClimber.SIZE {
                nextXlign.simple[j] = max(farmk.xlign[i].simple[j],
                                         farmkplus1.xlign[i].simple[j])
                nextYlign.simple[j] = max(farmk.ylign[i].simple[j],
                                         farmkplus1.ylign[i].simple[j])
            }
        #if DEBUG
            print("xlign[%d]:\n", i)
            DISPLAYTREE(xlign[i].simple)
            print("ylign[%d]:\n", i)
            DISPLAYTREE(ylign[i].simple)
        #endif
        }
    }


    /// Get the first vacant padi in the slab
    // INPUT PARAMETER:
    // 1) xydike    a pointer to an 2 elements array to hold the x y dike
    //
    // RETURN VALUES:
    // When success, return TRUE and xydike filled with the x y dikes
    // When fail, return FALSE
    func firstPadi(xydike : inout [Int]) -> Bool
    {
      //int i, j, off,
        let totalbyte = ((AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N) >> 3) + 1
        
        // clear the bitmap
        for i in 0 ..< totalbyte  {
            bitmap[i] = 0x0
        }

      // search through the bitmap for vacant padi
        for py in 0 ..< AdaptiveSkeletonClimber.N {
            // for each horizontal strip
            var xdike = xlign[py].simple[1]
            while (xdike > 0) {  // for each simple x dike
                var off = py * AdaptiveSkeletonClimber.N + Dike.start(xdike)
                if ((bitmap[off >> 3] & (CUnsignedChar(0x80 >> (off & 0x07)))) == 0) {
                    // vacant padi
                    xydike[0] = xdike;
                    xydike[1] = ylign[Dike.start(xdike)].simple[py + AdaptiveSkeletonClimber.N]
                    let endpy = py + Dike.length(xydike[1])
                    
                    // mark this padi as occupied
                    for j in py ..< endpy {
                        // mark ONLY the left side of the padi
                        bitmap[off >> 3] |= CUnsignedChar(0x80 >> (off & 0x07))
                        off += AdaptiveSkeletonClimber.N
                    }
                    return true
                }
                xdike = xlign[py].nextSimple(xdike)
            }
        }
        return false
    }


    // Get next vacant padi in the slab
    // INPUT and OUTPUT are same as FirstPadi()
    func nextPadi(xydike : inout [Int]) -> Bool {
        // continue the search for vacant padi
        // for each horizontal strip
        while (py < AdaptiveSkeletonClimber.N) {
            if (xdike > 0) {
                xdike = xlign[py].nextSimple(xdike)
            } else {
                xdike = xlign[py].simple[1]
            }
            // for each simple x dike
            while (xdike > 0) {
                var off = py * AdaptiveSkeletonClimber.N + Dike.start(xdike)
                if ((bitmap[off >> 3] & (CUnsignedChar(0x80 >> (off & 0x07)))) == 0) {
                    // vacant padi
                    xydike[0] = xdike
                    xydike[1] = ylign[Dike.start(xdike)].simple[py + AdaptiveSkeletonClimber.N];
                    let endpy = py + Dike.length(xydike[1])
                    // mark this padi as occupied
                    for _ in py ..< endpy {
                        // mark ONLY the left side of the padi
                        bitmap[off >> 3] |= CUnsignedChar(0x80 >> (off & 0x07))
                        off += AdaptiveSkeletonClimber.N
                    }
                    return true
                }
                xdike = xlign[py].nextSimple(xdike)
            }
            py += 1
        }
        return false
    }
}
