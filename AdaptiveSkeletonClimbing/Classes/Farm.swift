//
//  Farm.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 10/07/2020.
//

import Foundation

// Another performance issue is about search all overlapping padi
// during padi generation. You may think some tricky approach would
// be faster. I have previously used the UsedBy[] array to keep
// track all occupiant padi. But the procedure seems to run in
// O(n*n) time in the worst cases, where n is the number of dikes
// to visit. For each xstrip (n strips), you have to search
// the binary tree for competitors (worst case 2n dikes visited).
// On the other hand, if you search the existing padi one by one,
// the algorithm is almost n*n padi to visit. That is, seems no
// gain. I have not tested which one will perform better. One
// phenomenon is worth for consideration. The padi tends to be
// larger. If that is the case, I guess searching padi one by one
// will be better, since the overhead of bookkeeping approach is
// large. If on the other hand, padi is fine and small, bookkeeping
// approach may be good.
//#define PADISEARCH // If this flag on, the searching of competitors
                   // in ProducePadi will be a linear search
                   // through all existing padi. Otherwise, bookkeeping
                   // array UsedBy[] will be used for book keeping.

// In order to be more flexible, the "x" and "y" in the class farm may
// differ from the real x, y, z. Hence variable "Xis" and "Yis" are
// used to tell you what they are exactly.
// The following are some macros define what "Xis" and "Yis" are.

let PP_PADICONSTR = 0x01  // impose padi constrain
let PP_HRICECONSTR = 0x02  // impose highrice constrain

struct Lign {
    
}

struct Strip {
    
}

enum Dimension : Int {
    case x = 0
    case y = 1
    case z = 2
}

internal struct Farm {
  
    private var FixDimVal : Int = 0  // The value of the fixed dimension
    private var EDimIs : UInt = 0
    // bit   7       6   5 4     3 2  1 0
    // mean  empty?      FixDim  Yis  Xis
    // tells you what "x" and "y" actually are.
    // and the fixed dimension. Whether the farm has no isosurface crossing
    
    public var xlign = [Lign](repeating: Lign(), count: AdaptiveSkeletonClimber.N + 1)
    public var ylign = [Lign](repeating: Lign(), count: AdaptiveSkeletonClimber.N + 1)
    public var xstrip = [Strip](repeating: Strip(), count: AdaptiveSkeletonClimber.N)
    public var padilist = DoublyLinkedList<Padi>()  // hold the generated padis

  
    public func cleanUp() {
        if (!padilist.isEmpty) {
            padilist.removeAll()
        }
    }
    
    public mutating func initialize(xis : Dimension, yis : Dimension, fixdimval : Int,
                           xocc : [Bool], yocc : [Bool], xver : Int, yver : [Int]) {
        assert(!(fixdimval<0 || fixdimval > AdaptiveSkeletonClimber.N || xis == yis), "[Farm::Init]: input value invalid\n")
          
        var offx : Int
        var multx : Int
        var offy : Int
        var multy : Int
        var posx : Int
        var posy : Int
        
        self.FixDimVal = fixdimval
        self.EDimIs = 0
        self.EDimIs = 0x03 & (~(xis.rawValue | yis.rawValue))
        self.EDimIs = (EDimIs << 2) | (yis.rawValue & 0x03)
        self.EDimIs = (EDimIs << 2) | (xis.rawValue & 0x03)
        
        if (xis == .x && yis == .y) {
            // xyfarm
            multx = 1
            offx = FixDimVal * (AdaptiveSkeletonClimber.N + 1)
            multy = 1
            offy = FixDimVal * (AdaptiveSkeletonClimber.N + 1)
        } else if (xis == .x && yis == .z) {
            // xzfarm
            multx = AdaptiveSkeletonClimber.N + 1
            offx = FixDimVal;
            multy = 1
            offy = FixDimVal * (AdaptiveSkeletonClimber.N + 1);
        } else if (xis == .y && yis == .z) {
            // yzfarm
            multx = AdaptiveSkeletonClimber.N + 1
            offx = FixDimVal
            multy = AdaptiveSkeletonClimber.N + 1
            offy = FixDimVal
        } else {
            assert(false, "[Farm::init]: I don't know how to init\n")
        }
        var nonempty = false
        for i in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            posx = (i * multx + offx) * AdaptiveSkeletonClimber.SIZE;
            posy = (i * multy + offy) * AdaptiveSkeletonClimber.SIZE;
            xlign[i].initialize(&(xocc[posx]), &(xver[posx]))
            ylign[i].initialize(&(yocc[posy]), &(yver[posy]))
            nonempty = nonempty || (xocc[posx + 1] || yocc[posy + 1])
        }
        if (!nonempty) {
            setEmpty();
        }
        // xstrip will be inited in the subroutine ProducePadi()
    }
    
    public func emptyQ() -> Bool {
        return (EDimIs & 0x80) != 0
    }
    
    public mutating func unsetEmpty() {
        EDimIs &= 0x7f
    }
    
    public mutating func setEmpty() {
        EDimIs |= 0x80
    }
    
    public func XisV() -> PadiSide {
        return PadiSide(rawValue: Int((EDimIs & 0x03)))!
    }
    
    public func YisV() -> PadiSide {
        return PadiSide(rawValue: Int((EDimIs >> 2) & 0x03))!
    }
    
    public func fixDimV() -> PadiSide {
        return PadiSide(rawValue: Int((EDimIs >> 4) & 0x03))!
    }
    
    public func fixDimValV() -> Int {
        return FixDimVal
    }
    
    func TagXStrip(padi : Padi)
    {
        for j in Start(padi.dike[LEFT]) ..< End(padi.dike[LEFT]) {
            xstrip[j].usedby[padi.dike[BOTTOM]] = padi;
        }
    //  ShowTagMap(xstrip);
    }


    func UntagXStrip(padi : Padi)
    {
        for j in Start(padi.dike[LEFT]) ..< End(padi.dike[LEFT]) {
            if (xstrip[j].usedby[padi.dike[BOTTOM]] == padi) {
                xstrip[j].usedby[padi.dike[BOTTOM]] = nil
            } else {
                print("[Farm::UnTagXStrip]: possible some bug in tagging the data UsedBy\n");
                print("padi %d x %d want to untag,\n", padi.dike[BOTTOM], padi.dike[LEFT]);
                if (xstrip[j].usedby[padi.dike[BOTTOM]] != nil) {
                    printf ("[Farm::UnTagXStrip]: strip %d, dike %d, occupied by padi %d x %d\n", j, padi.dike[BOTTOM],
                            xstrip[j].usedby[padi.dike[BOTTOM]].dike[BOTTOM],
                            xstrip[j].usedby[padi.dike[BOTTOM]].dike[LEFT]);
                } else {
                    printf ("[Farm::UnTagXStrip]: strip %d, dike %d, occupied by no padi\n",  j, padi->dike[BOTTOM]);
                }
            }
        }
    //  ShowTagMap(xstrip);
    }

    func producePadi(block : Block, constrain : CUnsignedChar) -> DoublyLinkedList<Padi> {
      
        var ydike : [Dyke] = []
        ydike.reserveCapacity(AdaptiveSkeletonClimber.N)

      // Init xstrip
        for i in 0 ..< AdaptiveSkeletonClimber.N {
            xstrip[i].initialize(xlign, i, i + 1)
        }

        if (!padilist.isEmpty) {
            padilist.removeAll()
        }

        // from bottom to top xstrip
        for j in 0 ..< AdaptiveSkeletonClimber.N {
            // TODO: Write an iterator for 'simple'
            var i = xstrip[j].simple[1]
            while (i > 0)  {
                // Search for max J
                var jj = j + 1
                if (constrain & PP_PADICONSTR) {
                    while (jj < AdaptiveSkeletonClimber.N && xstrip[jj].simple[i] == i
                && Length(ylign[Start(i)].simple[j + AdaptiveSkeletonClimber.N]) > jj - j) {
                        // additional constrain due to produced padi
                        jj += 1
                    }
                } else if (constrain & PP_HRICECONSTR) {
                    while (jj < AdaptiveSkeletonClimber.N && xstrip[jj].simple[i] == i
                        && AdaptiveSkeletonClimber.N - ylign[Start(i)].simple[j] > jj - j) {
                            // additional constrain due to produced highrices
                            jj += 1
                    }
                } else {
                    while (jj < AdaptiveSkeletonClimber.N && xstrip[jj].simple[i] == i) {
                        jj += 1
                    }
                }
                let maxJ = jj - 1
                // Comment: Actually, the padi can grow downwards

                // Break this temporary padi into smaller padi along y, due to
                // binary restriction.
                var ydikecnt = 0
                MinDikeSet(j, maxJ, ydike, &ydikecnt);
                BreakDikeSet(ydike, ydikecnt, ylign, i);

                // Strategy used when there is overlapped padi:
                // For each overlapped padi,
                // 1) If current padi is enclosed by existing padi, throw current padi away
                // 2) If current padi enclosed by any existing padi, throw that padi away
                // 3) If current padi only overlap with existing padi, clip current padi
                //    by that padi.
                
                // for each candidate ydike
                for jj in 0 ..< ydikecnt {
                
                    var holder : [Padi] = []
                    holder.reserveCapacity(AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N)
                    var currpadi = Padi(i, ydike[jj], self, block)

                    // for each padi which is broken up by existing padi
                    repeat {
                                            
                        // consider clipped padi
                        if (!holder.isEmpty) {
                            // pick one element from array
                            currpadi = holder.popLast()!                            
                        }

                        // Check whether it is already occupied. And find out competitors.
                        var competitors : [Padi] = []
                        competitors.reserveCapacity(max(1, AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.NLEVEL))
                        
    #if PADISEARCH
                        // Using straighforward linear search all existing padi
                        for tmppadi in padilist {
                            if (tmppadi.overlapQ(currpadi)) {
                                competitors.append(tmppadi)
                            }
                        }
    #else
                        // This method of searching competitor may not be very efficient
                        for k in Start(currpadi.dike[PadiSide.left.rawValue]) ..< End(currpadi.dike[PadiSide.left.rawValue]) {
                            xstrip[k].UsedBy(currpadi.dike[PadiSide.bottom.rawValue], competitors)
                        }
    #endif
                        var padisuccess = true
                        for competitor in competitors {
                            // Check whether currpadi is enclosed by any competitor
                            if (currpadi.enclosedByQ(competitor)) {
                                // no need to continue, simply delete current padi
    #if DEBUG
                                print("remove current padi %d x %d\n", currpadi.dike[PadiSide.bottom.rawValue], currpadi.dike[PadiSide.left.rawValue])
    #endif
                                //currpadi = nil
                                padisuccess = false
                                break
                                                        
                            } else if (competitor.enclosedByQ(currpadi)) {
                                // If currpadi enclose competitor padi, just throw competitor away
    #if DEBUG
                                print("remove competitor padi %d x %d\n", competitor[k].dike[PadiSide.bottom.rawValue], competitor[k].dike[PadiSide.left.rawValue])
    #endif
                                UntagXStrip(competitor);
                                padilist.remove(competitor);
//                                delete competitor[k];
//                                competitor[k] = NULL;
                            } else {
                                // only partial overlaid, break the current padi
                
    #if DEBUG
                                print("before: break current padi %d x %d\n", currpadi.dike[PadiSide.bottom.rawValue], currpadi.dike[PadiSide.left.rawValue]);
                                print("clipped by padi %d x %d\n", competitor[k].dike[PadiSide.bottom.rawValue], competitor[k].dike[PadiSide.left.rawValue])
    #endif
                                currpadi.clipBy(competitor, &holder, self, block)
                                //delete currpadi;
                                //currpadi = NULL;
                                padisuccess = false
    #if DEBUG
                                print("after: break current padi %d x %d\n", currpadi.dike[PadiSide.bottom.rawValue], currpadi.dike[PadiSide.left.rawValue])
    #endif
                  
                                // no need to continue, since the clipped portion have to go through the whole test
                                break
                            }
                        }

                        if (padisuccess) {
                            // Tag those occupied region
                            TagXStrip(padi: currpadi)
                            // Insert the current padi into the doubly linked list
                            padilist.append(currpadi)
    #if DEBUG
                            print("current padi born %d x %d\n", currpadi.dike[PadiSide.bottom.rawValue], currpadi.dike[PadiSide.left.rawValue]);
    #endif
                        }
                    } while (!holder.isEmpty)
                }
                i = xstrip[j].NextSimple(i)
            }
        }
        return padilist
    }


    // 2nd time init (reuse) simple array in the class Lign
    // You should be careful to call this subroutine, since this calling will
    // destroy the data stored in simple[] array previously.
    // This function make use of the info store in the input Strip.
    func InitSimpleByPadi() {

        // clear the value in the simple array of xlign and ylign
        for i in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            xlign[i].simple = [Lign.nullsimple](repeating: Lign.nullsimple, count: Lign.simplesize)
            ylign[i].simple = [Lign.nullsimple](repeating: Lign.nullsimple, count: Lign.simplesize)
        }

        // Init only the bottom level of the simple[] arrays using info in padilist
        for currpadi in padilist {
            // record only the left bottom corner in the simple array
            let ldikestart = Start(currpadi.dike[LEFT])
            let ldikeend   = End(currpadi.dike[LEFT])
            let bdikestart = Start(currpadi.dike[BOTTOM])
            let bdikeend   = End(currpadi.dike[BOTTOM])
            for i in ldikestart ..< ldikeend {
                xlign[i].simple[bdikestart + AdaptiveSkeletonClimber.N] = currpadi.dike[BOTTOM];
            }
            for i in bdikestart ..< bdikeend {
                ylign[i].simple[ldikestart + AdaptiveSkeletonClimber.N] = currpadi.dike[LEFT];
            }
        }

        // for each xlign and ylign
        // propagate the available info upward
        for i in 0 ..< AdaptiveSkeletonClimber.N {
            for j in (1 ..< AdaptiveSkeletonClimber.N).reversed() {
                xlign[i].simple[j] = xlign[i].simple[j << 1]
                ylign[i].simple[j] = ylign[i].simple[j << 1]
            }
            xlign[i].simple[0] = -1 // undefined
            ylign[i].simple[0] = -1
        }

        // for each xlign and ylign if the value == -1,
        // propagate info downward
        for i in 0 ..< AdaptiveSkeletonClimber.N {
            for j in 1 ..< AdaptiveSkeletonClimber.SIZE {
                if (xlign[i].simple[j] == -1) {
                    // no value filled
                    if (0x01 & j) {
                        // odd numbered dike
                        xlign[i].simple[j] = j
                    } else {
                        // even numbered dike, inherent from parent
                        xlign[i].simple[j] = xlign[i].simple[j >> 1]
                    }
                }
                if (ylign[i].simple[j] == -1) {
                    // no value filled
                    if (0x01 & j) {
                        // odd numbered dike
                        ylign[i].simple[j] = j;
                    } else {
                        // even numbered dike, inherent from parent
                        ylign[i].simple[j] = ylign[i].simple[j >> 1]
                    }
                }
            }
        }

        // copy the simple info to xlign[N] and ylign[N]
        for i in 0 ..< AdaptiveSkeletonClimber.SIZE {
            xlign[AdaptiveSkeletonClimber.N].simple[i] = xlign[AdaptiveSkeletonClimber.N - 1].simple[i];
            ylign[AdaptiveSkeletonClimber.N].simple[i] = ylign[AdaptiveSkeletonClimber.N - 1].simple[i];
        }

    #if DEBUG
        for i in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            print("xlign[%d]:\n",i);
            DISPLAYTREE(xlign[i].simple);
            print("ylign[%d]:\n",i);
            DISPLAYTREE(ylign[i].simple);
        }
    #endif
    }


    func InitSimpleBySlab(below : Slab, above : Slab) {
      
        for j in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            for i in 0 ..< AdaptiveSkeletonClimber.SIZE {
                xlign[j].simple[i] = max(below.xlign[j].simple[i], above.xlign[j].simple[i])
                ylign[j].simple[i] = max(below.ylign[j].simple[i], above.ylign[j].simple[i])
            }
        }
    }
}
