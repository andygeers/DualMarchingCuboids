//
//  Strip.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 20/07/2020.
//

import Foundation

enum StripUsage {
    case completeUsed // 1
    case partialUsed  // 2
    case notUsed      // 3
}

/// Strip is the area between 2 consecutive dikes or ligns.
struct Strip {
    public var simple = [Int](repeating: 0, count: AdaptiveSkeletonClimber.SIZE)
    public var usedby = [Padi?](repeating: nil, count: AdaptiveSkeletonClimber.SIZE)
    
    static func showTagMap(_ xstrip : [Strip]) {
        var tagmap = [Bool](repeating: false, count: AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N)
        
        for j in 0 ..< AdaptiveSkeletonClimber.N {
            for k in 1 ..< AdaptiveSkeletonClimber.SIZE {
                if (xstrip[j].usedby[k] != nil) {
                    for i in Dike.start(k) ..< Dike.end(k) {
                        tagmap[j * AdaptiveSkeletonClimber.N + i] = true
                    }
                }
            }
        }

        for j in (0 ..< AdaptiveSkeletonClimber.N).reversed() {
            for i in 0 ..< AdaptiveSkeletonClimber.N {
                if (tagmap[j * AdaptiveSkeletonClimber.N + i]) {
                    print("* ")
                } else {
                    print(". ")
                }
            }
            print("\n");
        }
    }


    public init(lign : [Lign], pos1: Int, pos2: Int) {
        for i in 0 ..< AdaptiveSkeletonClimber.SIZE {
            simple[i] = max(lign[pos1].simple[i], lign[pos2].simple[i])
        }
        #if DEBUG
        DISPLAYTREE(simple)
        #endif
    }


    // This function test whether the input dike is already occupied by
    // any other dikes
    //
    // INPUT PARAMETERS:
    // 1) dike      The dike enquiried
    // 2) occup     An array to hold the competitor dike
    // 3) cnt       No of element in occup[]
    //
    // OUTPUT PARAMETERS:
    // return COMPLETEUSED if completely occupied
    // return PARTIALUSED if partially occupied
    // return NOTUSED if nobody occupied
    // In any cases that enquiy dike is partially or compeletely occupied by
    // other dike, the competitors will be append into the occup[]
    @discardableResult
    func usedBy(dike : Int, occup : inout [Padi]) -> StripUsage {
        assert(!(dike < 1 || dike > AdaptiveSkeletonClimber.SIZE), "[Strip::UsedBy]: invalid input value\n")
              
      // Check occupancy upward the tree
        var i = dike
        while i > 0 {
            if let usedbyDike = usedby[i] {
                // the input strip is enclosed by larger strip
                // assume no overlapping, the caller should make sure this point
                if (!occup.contains(where: { $0 === usedbyDike })) {
                    occup.append(usedbyDike)
                }
                return .completeUsed; // completely used up
            }
            i >>= 1
        }

        // Check occupancy downward the tree
        var dikelevel = Dike.level(dike)
        let dikelength = Dike.length(dike)
        var occlength = 0
        var lb = dike
        var ub = dike
        while (dikelevel <= AdaptiveSkeletonClimber.NLEVEL) {
            for i in lb ... ub {
                if let usedbyDike = usedby[i] {
                    // search whether this padi already in the array
                    if (occup.contains(where: { $0 === usedbyDike })) {
                        // of course we assume there is very few competitors
                        // otherwise, this search may be time consuming
                        break
                    } else {
                        // record it in the array only when it is new competitor
                        occup.append(usedbyDike)
                    }
                    // assume all competitor come to this point are unique
                    occlength += Dike.length(i)
                    if (dikelength == occlength) {
                        // completely used up
                        return .completeUsed
                    }
                }
            }
            dikelevel += 1
            lb = lb << 1
            ub = (ub << 1) + 1
        }
        if (occlength > 0) {
            return .partialUsed
        } else {
            return .notUsed
        }
    }
}
