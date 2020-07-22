//
//  Dike.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 18/07/2020.
//

import Foundation
import CoreGraphics

struct Dike {
    
    static var G_LevelTable = [Int](repeating: 0, count: AdaptiveSkeletonClimber.DSIZE)
    static var G_LengthTable = [Int](repeating: 0, count: AdaptiveSkeletonClimber.DSIZE)
    static var G_NextDikeTable = [Int](repeating: 0, count: AdaptiveSkeletonClimber.DSIZE)
    static var G_StartTable = [Int](repeating: 0, count: AdaptiveSkeletonClimber.DSIZE)
    static var G_EndTable = [Int](repeating: 0, count: AdaptiveSkeletonClimber.DSIZE)
    
    static func level(_ i : Int) -> Int {
        assert(i < AdaptiveSkeletonClimber.DSIZE, "[Level]: Tablelookup out of bound %d\n")
        return G_LevelTable[i]
    }

    static func length(_ i : Int) -> Int {
        assert(i < AdaptiveSkeletonClimber.SIZE, "[Length]: Tablelookup out of bound\n")
        return G_LengthTable[i]
    }

    static func nextDike(_ i : Int) -> Int {
        assert(i < AdaptiveSkeletonClimber.SIZE, "[NextDike]: Tablelookup out of bound\n")
        return G_NextDikeTable[i]
    }

    static func start(_ i : Int) -> Int {
        assert(i < AdaptiveSkeletonClimber.SIZE, "[Start]: Tablelookup out of bound\n")
        return G_StartTable[i]
    }

    static func end(_ i : Int) -> Int {
        assert(i < AdaptiveSkeletonClimber.SIZE, "[End]: Tablelookup out of bound\n")
        return G_EndTable[i]
    }
    
    /// Init the various dike lookup table
    internal static func DikeTableInit() {
        for k in 1 ..< AdaptiveSkeletonClimber.DSIZE {
            G_LevelTable[k]    = Int(floor(CoreGraphics.log10(Double(k)) / CoreGraphics.log10(2.0)))
            G_LengthTable[k]   = 1 << (AdaptiveSkeletonClimber.NLEVEL - G_LevelTable[k])
            G_NextDikeTable[k] = (k & (k + 1)) > 0 ? k + 1 : 0
            G_StartTable[k]    = (k << (AdaptiveSkeletonClimber.NLEVEL - G_LevelTable[k])) - AdaptiveSkeletonClimber.N
            G_EndTable[k]      = G_StartTable[k] + G_LengthTable[k]
        }
    }


    /// This function generates a list of dike which fill up the given
    /// range [minidx,maxidx]. minidx and maxidx's values are in the range
    /// [0, N]. It is the index at the bottom level with the leftmost one has
    /// index 0.
    /// "dike" is a user provided int array used to hold the generated dike number
    /// "dikecnt" is the total no of dike in the array. User should init it to 0
    /// if the array "dike" is empty
    internal static func MinDikeSet(minidx : Int, maxidx : Int, dike : inout [Int]) {
        let mask = 1

        assert(!(minidx<0 || minidx > AdaptiveSkeletonClimber.N || maxidx < 0 || maxidx > AdaptiveSkeletonClimber.N), "[MinDikeSet]: invalid input\n")

        var minimum = min(minidx, maxidx)
        var maximum = max(minidx, maxidx)
        minimum = minimum + AdaptiveSkeletonClimber.N
        maximum = maximum + AdaptiveSkeletonClimber.N + 1

        var t = 0
        
        while (minimum < maximum) {
            var currdike = minimum
            if (currdike & mask > 0) {
                // odd number
                dike.append(currdike)
                minimum += Dike.length(currdike)
            } else {
                // even number
                t = Dike.length(currdike)
                // grow the dike until overflow or dike is odd
                while (minimum + (t << 1) <= maximum && (currdike & mask) != 1) {
                    t <<= 1
                    currdike >>= 1
                }
                dike.append(currdike)
                minimum += t
            }
        }
        #if DEBUG
        for i in dike {
            print("%d ", i)
        }
        print("\n");
        #endif
    }


    // Break the dike into even smaller dikes if not all same-index-ydike are
    // simple
    internal static func BreakDikeSet(ydike : inout [Int], ylign : [Lign], i : Int) {
        assert(!(i<1 || i>=AdaptiveSkeletonClimber.SIZE), "[BreakDikeSet]: invalid input value\n")
                  
        var jj = 0
        while jj < ydike.count {
            var isAllSimple = true
            repeat {
                isAllSimple = true
                for ii in Dike.start(i) ... Dike.end(i) {
                    if (ylign[ii].occ(ydike[jj]) == Lign.COMPLEX) {
                        ydike[jj] <<= 1                // let this be its left child
                        ydike.append(ydike[jj] + 1)    // append right child at the end
                        isAllSimple = false
                        break;
                    }
                }
            } while (!isAllSimple)
            jj += 1
        }
    }
}
