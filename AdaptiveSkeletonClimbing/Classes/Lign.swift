//
//  Lign.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 18/07/2020.
//

import Foundation

struct Lign {
    public var block : Block
    public var occOffset : Int
    public var dimension : Dimension
    
    static let COMPLEX = 3
    
    var simple = [Int](repeating: Int.max, count: AdaptiveSkeletonClimber.SIZE)
    
    init(block: Block, offset: Int, dimension : Dimension) {
        self.block = block
        self.occOffset = offset
        self.dimension = dimension
        
        simpleQ(myid: 1, inherent: -1)
        
        #if DEBUG
        DISPLAYTREE(simple)
        #endif
    }
    
    func occ(index: Int) -> CChar {
        switch (dimension) {
            case .x:
                return block.xocc[occOffset + index]
            
            case .y:
                return block.yocc[occOffset + index]
            
            default:
                return 0
        }
    }

    /// inherent hold the id of the topmost simple dike
    /// It contains -1 if the previous top dike are not simple
    /// it also hold the info propogated downward the binary tree
    @discardableResult
    mutating func simpleQ(myid : Int, inherent : Int) -> Int {
        if (myid >= AdaptiveSkeletonClimber.SIZE) {
            // return the bottom leaf's id
            return myid >> 1
        }

        if (inherent > 0) {
            // parent is simple
            if (0x01 & myid > 0) {
                // I am right child, I must be simple
                simple[myid] = myid
            } else {
                // I am left child, then inherent the simplicity
                simple[myid] = inherent
            }
            // propogate info downward
            // visit left child
            simpleQ(myid: myid << 1, inherent: simple[myid])
            // visit right child
            simpleQ(myid: (myid << 1) + 1, inherent: simple[myid])
        } else {
            // parent is not simple
            if (occ(index: myid) < Lign.COMPLEX) {
                // but I am simple
                simple[myid] = myid
                // propogate info downward
                // visit left child
                simpleQ(myid: myid << 1, inherent: simple[myid])
                // visit right child
                simpleQ(myid: (myid << 1) + 1, inherent: simple[myid])
            } else {
                // I am not simple also, ask my descendant for simple
                // visit left child
                let descendant = simpleQ(myid: myid << 1, inherent: simple[myid])
                // visit right child
                simpleQ(myid: (myid << 1) + 1, inherent: simple[myid])
                simple[myid] = descendant
            }
        }

        #if DEBUG
        DISPLAYTREE(simple)
        #endif

        // propogate info upward
        return simple[myid]
    }


    // Propagate info in the simple array upward
    mutating func propagateUpSimple() {
        for i in (1 ..< AdaptiveSkeletonClimber.N).reversed() {
            simple[i] = simple[i << 1]
        }
        simple[0] = Int.max
    }


    // Propagate info in the simple array downward
    mutating func propagateDownSimple() {
        for i in 1 ..< AdaptiveSkeletonClimber.SIZE {
            if (simple[i] == Int.max) {
                // no value filled
                if (0x01 & i > 0) {
                    // odd
                    simple[i] = i
                } else {
                    // even inherent from parent
                    simple[i] = simple[i >> 1]
                }
            }
        }
    }


    mutating func maxSimple(neighbor : Lign) {
        for i in 1 ..< AdaptiveSkeletonClimber.SIZE  {
            simple[i] = max(simple[i], neighbor.simple[i])
        }
    }

    /// fill up the vancany in the bottommost level of the simple[] with
    /// the max sized dike
    mutating func fillSimpleVacancy() {
        var dikearr : [Int] = []
        dikearr.reserveCapacity(AdaptiveSkeletonClimber.N)
        var empbegin = 0
        for i in 0 ..< AdaptiveSkeletonClimber.N {
            if (simple[i + AdaptiveSkeletonClimber.N] != Int.max) {
                if (empbegin < i) {
                    Dike.MinDikeSet(minidx: empbegin, maxidx: i - 1, dike: &dikearr)
                    for dikel in dikearr {
                        simple[Dike.start(dikel) + AdaptiveSkeletonClimber.N] = dikel
                    }
                    empbegin = i
                }
                empbegin += 1
            }
        }
        if (empbegin < AdaptiveSkeletonClimber.N) {
            dikearr.removeAll(keepingCapacity: true)
            Dike.MinDikeSet(minidx: empbegin, maxidx: AdaptiveSkeletonClimber.N - 1, dike: &dikearr)
            for dikeval in dikearr {
                simple[Dike.start(dikeval) + AdaptiveSkeletonClimber.N] = dikeval
            }
       }
    }



    mutating func fillSpecSimpleVacancy() {
        var empbegin = 0
        for i in 0 ..< AdaptiveSkeletonClimber.N  {
            if (simple[i] != Int.max) {
                if (empbegin < i) {
                    for l in empbegin ..< i {
                        simple[l] = AdaptiveSkeletonClimber.N - (i - l)
                        empbegin = i
                    }
                    empbegin += 1
                }
            }
        }
        if (empbegin < AdaptiveSkeletonClimber.N) {
            for l in empbegin ..< AdaptiveSkeletonClimber.N {
                simple[l] = AdaptiveSkeletonClimber.N - (AdaptiveSkeletonClimber.N - l)
            }
        }
    }
}
