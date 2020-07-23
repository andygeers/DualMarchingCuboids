//
//  Block.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 09/07/2020.
//

import Foundation
import Euclid

func DISPLAYTREE(_ a : [Int], offset : Int = 0) {
    var values : [String] = []
    for di in 0 ... AdaptiveSkeletonClimber.NLEVEL {
        for dj in 0 ..< (1 << di) {
            values.append(String(format: "%d", Int(a[offset + (1 << di) + dj])))
        }
    }
    NSLog("%@", values.joined(separator: " "))
}

/// Block. It constrains the max size of highrice.
/// All the isosurface generation processes are done in this object.
internal struct Block {
    static let THINTHRESH = 0.25
    static let FATTHRESH = 0.5
        
    static let PP_HRICECONSTR = 0x02
    static var G_NonEmptyBlockCnt = 0
    static var G_mindpvalue = 0.0
    static var G_Stat_TriangleCnt = 0
    
    static var G_HandleBeauty = true
    
    static var edge : [Int] = [] {
        didSet {
            // TODO: Check if this works
            print("Reserving capacity for edge")
            edge.reserveCapacity(2 * 4 * 3 * AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N)
        }
    }
    static var pathcnt = [Int](repeating: 0, count: 8)
    static var path : [Int] = [] {
        didSet {
            // TODO: Check if this works
            print("Reserving capacity for path")
            path.reserveCapacity(2 * 6 * AdaptiveSkeletonClimber.N*AdaptiveSkeletonClimber.N + 1)
        }
    }
    
    func HIGHRICEDIM(s : String, h : HighRice) {
        print(s)
        NSLog(" %d x %d x [%d,%d]\n", h.dike[0], h.dike[1], h.bottom, h.top)
    }

    public let climber : AdaptiveSkeletonClimber
    
    public var offX : Int = 0
    public var offY : Int = 0
    public var offZ : Int = 0
    
    public var highricelist = DoublyLinkedList<HighRice>()
    public var xyfarm : [Farm] = []
    public var xzfarm : [Farm] = []
    public var yzfarm : [Farm] = []
    public var slab : [Slab] = []
    
    // A "global" way to store ver[] and occ[]
    // for all ligns. If ver[] and occ[] belongs to
    // lign, then each ver[] will be duplicated twice.
    public var xver = [Int](repeating: 0, count: (AdaptiveSkeletonClimber.N + 1) * (AdaptiveSkeletonClimber.N + 1) * AdaptiveSkeletonClimber.SIZE)
    public var yver = [Int](repeating: 0, count: (AdaptiveSkeletonClimber.N + 1) * (AdaptiveSkeletonClimber.N + 1) * AdaptiveSkeletonClimber.SIZE)
    public var zver = [Int](repeating: 0, count: (AdaptiveSkeletonClimber.N + 1) * (AdaptiveSkeletonClimber.N + 1) * AdaptiveSkeletonClimber.SIZE)
    public var xocc = [CChar](repeating: 0, count: (AdaptiveSkeletonClimber.N + 1) * (AdaptiveSkeletonClimber.N + 1) * AdaptiveSkeletonClimber.SIZE)
    public var yocc = [CChar](repeating: 0, count: (AdaptiveSkeletonClimber.N + 1) * (AdaptiveSkeletonClimber.N + 1) * AdaptiveSkeletonClimber.SIZE)
    public var zocc = [CChar](repeating: 0, count: (AdaptiveSkeletonClimber.N + 1) * (AdaptiveSkeletonClimber.N + 1) * AdaptiveSkeletonClimber.SIZE)

    
    // 4 small info are packed in one byte:
    // 1) Block is empty bit (no isosurface crossing)
    // 2) what X direction is  3) what Y direction is  4) what Z is
    // bit      7       6    5 4   3 2   1 0
    // means:   empty        Zis   Yis   Xis
    private var EXYZis : CUnsignedChar = 0
                                        
    
    private func XisQ() -> Dimension {
        return Dimension(rawValue: Int(EXYZis) & 0x03) ?? .x
    }
    private func YisQ() -> Dimension {
        return Dimension(rawValue: (Int(EXYZis)>>2) & 0x03) ?? .x
    }
    private func ZisQ() -> Dimension {
        return Dimension(rawValue: (Int(EXYZis)>>4) & 0x03) ?? .x
    }
    
    private mutating func setXis(_ xis : Dimension) {
        EXYZis = (EXYZis & 0xfc) | (UInt8(xis.rawValue) & 0x03)
    }
    private mutating func setYis(_ yis : Dimension) {
        EXYZis = (EXYZis & 0xf3) | ((UInt8(yis.rawValue) & 0x03) << 2)
    }
    private mutating func setZis(_ zis : Dimension) {
        EXYZis = (EXYZis & 0xcf) | ((UInt8(zis.rawValue) & 0x03) << 4)
    }
    
    public func isEmptyQ() -> Bool {
        return (EXYZis & 0x80) != 0
    }
    public mutating func unsetEmpty() {
        EXYZis &= 0x7f
    }
    public mutating func setEmpty() {
        EXYZis |= 0x80
    }
    
    public init(climber: AdaptiveSkeletonClimber) {
        self.climber = climber
    }
    
    public mutating func initialize(xis : Dimension, yis : Dimension, zis : Dimension,
                    offx : Int, offy : Int, offz : Int) {
        
        
        self.offX = offx
        self.offY = offy
        self.offZ = offz
        EXYZis = 0
        setXis(xis)
        setYis(yis)
        setZis(zis)
        highricelist = DoublyLinkedList<HighRice>()

        // init x y z occ[] and ver[]
        var nonempty : CChar = 0
        var mydata = VoxelData(climber: climber)
        for j in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            for i in 0 ..< AdaptiveSkeletonClimber.N + 1 {
                let pos = (j * (AdaptiveSkeletonClimber.N + 1) + i) * AdaptiveSkeletonClimber.SIZE
                mydata.reinit(x: -1, y: i, z: j, offx: offX, offy: offY, offz: offZ)
                Initocc(data: mydata, occ: &xocc, offset: pos)
                Initver(occ: xocc, ver: &xver, offset: pos)
                mydata.reinit(x: i, y: -1, z: j, offx: offX, offy: offY, offz: offZ)
                Initocc(data: mydata, occ: &yocc, offset: pos)
                Initver(occ: yocc, ver: &yver, offset: pos)
                mydata.reinit(x: i, y: j, z: -1, offx: offX, offy: offY, offz: offZ)
                Initocc(data: mydata, occ: &zocc, offset: pos)
                Initver(occ: zocc, ver: &zver, offset: pos)
                nonempty |= (xocc[pos+1] | yocc[pos+1] | zocc[pos+1])
            }
        }
        if (nonempty == 0) {
            setEmpty()
        } else {
            Block.G_NonEmptyBlockCnt += 1
        }
    }


    func Initocc(data : VoxelData, occ : inout [CChar], offset: Int) {
      
        // Construct bottom level of the binary tree
        for i in 0 ..< AdaptiveSkeletonClimber.N {
            let d1 = data[i]     // This is not because the cost of dereferencing,
            let d2 = data[i + 1] // but also operator[] is actually a function.
            let occD1 = ((d1 << 1) | (~d1 & 0x01))
            let occD2 = (((~d2 & 0x01) << 1) | d2)
            let newOcc = occD1 & occD2
            occ[offset + i + AdaptiveSkeletonClimber.N] = newOcc
        }

        // Recursively (iteratively) init occ from the bottom level to the top level
        for i in (1 ..< AdaptiveSkeletonClimber.N).reversed() {
            occ[offset + i] = occ[offset + i << 1] | occ[offset + (i << 1) + 1]
        }
        occ[offset] = 0 // undefined

    #if DEBUG
        DISPLAYTREE(occ.map { return Int($0) }, offset: offset)
    #endif
    }


    func Initver(occ : [CChar], ver : inout [Int], offset : Int) {
      
      // init the value of the bottom level
        for i in 0 ..< AdaptiveSkeletonClimber.N {
            if (occ[offset + i + AdaptiveSkeletonClimber.N] > 0) { // occ != 00
              ver[offset + i + AdaptiveSkeletonClimber.N] = i + AdaptiveSkeletonClimber.N
            } else {
              ver[offset + i + AdaptiveSkeletonClimber.N] = 0
            }
        }

      // Iteratively construct higher level ver[] from the bottom
        for i in (1 ..< AdaptiveSkeletonClimber.N).reversed() {
            if (ver[offset + i << 1] > 0) {
                // left child is not 00
                ver[offset + i] = ver[i<<1];
            } else if (ver[offset + (i << 1) + 1] > 0) {
                // right child is not 00
                ver[offset + i] = ver[(i << 1) + 1]
            } else {
                // both left and right child are 00
                ver[offset + i] = 0
            }
        }
      ver[0] = 0; // undefined

    #if DEBUG
      DISPLAYTREE(ver);
    #endif
    }
    
    func untagSlab(highRice: HighRice) {
        // Original implementation apparently does nothing??
    }
    
    func tagSlab(highRice: HighRice) {
        // Original implementation apparently does nothing??
    }

    mutating func produceHighRice(block: Block, farms : [Farm]) -> DoublyLinkedList<HighRice> {
    
        var xydike : [Int] = []
        var competecnt : Int
        var currhighrice : HighRice? = nil
        var holder : [HighRice] = []
        holder.reserveCapacity(AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N)
        var competitor = [HighRice?](repeating: nil, count: AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N)

        // Init the slabs
        slab.reserveCapacity(AdaptiveSkeletonClimber.N)
        slab.removeAll(keepingCapacity: true)
        for i in 0 ..< AdaptiveSkeletonClimber.N {
            slab.append(Slab(block: block, farmk: farms[i], farmkplus1: farms[i + 1]))
        }

        // Clean up the doubly linked list
        if (!highricelist.isEmpty) {
            highricelist = DoublyLinkedList<HighRice>()
        }

        for j in 0 ..< AdaptiveSkeletonClimber.N { // from bottom to top slab
            var go_on = slab[j].firstPadi(xydike: &xydike)
            while (go_on) {
                let x = xydike[0]
                let y = xydike[1]
                var jj = j + 1  // Search for max J
                while (jj < AdaptiveSkeletonClimber.N && slab[jj].xlign[Dike.start(y)].simple[x] == x
                    && slab[jj].ylign[Dike.start(x)].simple[y] == y) {
                        
                        jj += 1
                }
                jj -= 1
                // Comment: Actually, the highrice can grow downwards

                // Strategy used when there is overlapped highrice:
                // For each overlapped highrice,
                // 1) If current highrice is enclosed by existing highrice, throw current highrice away
                // 2) If current highrice enclosed by any existing highrice, throw that highrice away
                // 3) If current highrice only overlap with existing highrice, clip current
                //    highrice by that highrice.
                holder.removeAll(keepingCapacity: true)
                currhighrice = HighRice(climber: block.climber, xdike: x, ydike: y, b: j, t: jj)
                repeat {
                    // for each highrice which is broken up by overlapped highrice
                    if (!holder.isEmpty) { // consider clipped highrice
                        // pick one element from array
                        currhighrice = holder.popLast()!
                    }

                    // Check whether it is already occupied. And find out competitors.
            //#ifdef HIGHRICESEARCH
                    competecnt = 0
                    for tmphighrice in highricelist {
                        if (tmphighrice.overlapQ(padi: currhighrice!)) {
                            competitor[competecnt] = tmphighrice
                            competecnt += 1
                        }
                    }
            //#else
                    // book keeping routine not yet implemented
            //#endif

                    var highricesuccess : Bool = true
                    for k in 0 ..< competecnt {
                        let competitorK = competitor[k]!
                        
                      // Check whether currhighrice is enclosed by any competitor
                        if (currhighrice!.enclosedByQ(competitorK)) {
                       // no need to continue, simply delete current highrice
            #if DEBUG
                            HIGHRICEDIM(s: "remove current highrice", h: currhighrice!)
            #endif
                            currhighrice = nil
                            highricesuccess = false
                            break;
                      
                        // If currhighrice enclose competitor currhighrice, just throw competitor away
                        } else if (competitorK.enclosedByQ(currhighrice!)) {
            #if DEBUG
                            HIGHRICEDIM(s: "remove competitor highrice", h: competitorK)
            #endif
                            untagSlab(highRice: competitorK)
                            highricelist.remove(where: { $0 === competitorK })
                            competitor[k] = nil
                      
                        } else {
                            // only partial overlaid, break the current highrice
                      
            #if DEBUG
                            HIGHRICEDIM(s: "before: break current highrice", h: currhighrice!)
                            HIGHRICEDIM(s: "clipped by highrice", h: competitorK)
            #endif
                            currhighrice!.clipBy(clipper: competitorK, holder: &holder, climber: climber)
                            currhighrice = nil
                            highricesuccess = false
                            // no need to continue, since the clipped portion have to go through the whole test
                            break
                        }
                    }

                    if (highricesuccess) {
                        // Tag those occupied region
                        tagSlab(highRice: currhighrice!)
                        // Insert the current padi into the doubly linked list
                        highricelist.append(currhighrice!)
                        #if DEBUG
                        HIGHRICEDIM(s: "current highrice born", h: currhighrice!)
                        #endif
                    }
                } while (!holder.isEmpty)
                go_on = slab[j].nextPadi(xydike: &xydike)
            }
        }
        
        return highricelist
    }



    mutating func initSimpleByHighRice() {
                    
        // lcfarm is localfarm, its xlign is used as temporary
        // array for xzfarm[].xlign[] and its ylign is used as
        // temporary for yzfarm[].xlign[].
        var lcfarm = [Farm](repeating: Farm(block: self), count: AdaptiveSkeletonClimber.N + 1)
        var hzfarm = [Farm](repeating: Farm(block: self), count: AdaptiveSkeletonClimber.N + 1)

        // Don't think we need this, since a newly initialized Lign is always 'nullsimple' now
//        for k in 0 ..< AdaptiveSkeletonClimber.N+1 {
//            for j in 0 ..< AdaptiveSkeletonClimber.N+1 {
//                lcfarm[k].xlign[j].simple = [Lign::nullsimple](repeating: Lign(), Lign::simplesize)
//              lcfarm[k].ylign[j].simple = [Lign::nullsimple](repeating: Lign::nullsimple(), Lign::simplesize)
//              hzfarm[k].xlign[j].simple = [Lign::nullsimple](repeating: Lign::nullsimple(), Lign::simplesize)
//              xyfarm[k].xlign[j].simple = [Lign::nullsimple](repeating: Lign::nullsimple(), Lign::simplesize)
//              xyfarm[k].ylign[j].simple = [Lign::nullsimple](repeating: Lign::nullsimple(), Lign::simplesize)
//              xzfarm[k].xlign[j].simple = [Lign::nullsimple](repeating: Lign::nullsimple(), Lign::simplesize)
//              xzfarm[k].ylign[j].simple = [Lign::nullsimple](repeating: Lign::nullsimple(), Lign::simplesize)
//              yzfarm[k].xlign[j].simple = [Lign::nullsimple](repeating: Lign::nullsimple(), Lign::simplesize)
//              yzfarm[k].ylign[j].simple = [Lign::nullsimple](repeating: Lign::nullsimple(), Lign::simplesize)
//            }
//        }

        for curr in highricelist {
            let xznear = Dike.start(curr.dike[PadiSide.left.rawValue])
            let xzfar  = Dike.end(curr.dike[PadiSide.left.rawValue])
            let yznear = Dike.start(curr.dike[PadiSide.top.rawValue])
            let yzfar  = Dike.end(curr.dike[PadiSide.top.rawValue])
            let xzdikestart = AdaptiveSkeletonClimber.N + yznear
            let yzdikestart = AdaptiveSkeletonClimber.N + xznear
            let xzdike = curr.dike[PadiSide.top.rawValue]
            let yzdike = curr.dike[PadiSide.left.rawValue]
            // init simple[] of xyfarm
            for j in xznear ..< xzfar {
                xyfarm[curr.bottom].xlign[j].simple[xzdikestart] = xzdike
                hzfarm[curr.top + 1].xlign[j].simple[xzdikestart] = xzdike
                let N_l = AdaptiveSkeletonClimber.N - (xzfar - j)
                for i in yznear ..< yzfar {
                    xyfarm[curr.bottom].ylign[i].simple[j] = max(N_l, xyfarm[curr.bottom].ylign[i].simple[j])
                    xyfarm[curr.top + 1].ylign[i].simple[j] = max(N_l, xyfarm[curr.top + 1 ].ylign[i].simple[j])
                }
            }

            for j in curr.bottom ... curr.top {
                // set the xzfarm
                xzfarm[xznear].xlign[j].simple[xzdikestart] = xzdike
                lcfarm[xzfar ].xlign[j].simple[xzdikestart] = xzdike
                // set the yzfarm
                yzfarm[yznear].xlign[j].simple[yzdikestart] = yzdike
                lcfarm[yzfar ].ylign[j].simple[yzdikestart] = yzdike
            }
            // Since there is no binary restriction along Z direction, simple[]
            // is coded differently. only [0, N-1] entries are used. Each entry
            // holds N-l where l is the no of unit dikes from current dike to
            // the boundary imposed by the highrice faces.
            for j in curr.bottom ... curr.top {
                let N_l = AdaptiveSkeletonClimber.N - (curr.top - j + 1)
                // Note: not i<=yzfar, cause extra fragmentation
                for i in yznear ..< yzfar {
                    xzfarm[xznear].ylign[i].simple[j] = max(N_l, xzfarm[xznear].ylign[i].simple[j])
                    xzfarm[xzfar ].ylign[i].simple[j] = max(N_l, xzfarm[xzfar ].ylign[i].simple[j])
                }
                for i in xznear ..< xzfar {
                    yzfarm[yznear].ylign[i].simple[j] = max(N_l, yzfarm[yznear].ylign[i].simple[j])
                    yzfarm[yzfar ].ylign[i].simple[j] = max(N_l, yzfarm[yzfar ].ylign[i].simple[j])
                }
            }
        }

        // Init the unused entries in the simple[] to appropiate values
        for k in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            for j in 0 ..< AdaptiveSkeletonClimber.N {
                // fill the specially coded simple[]
                xyfarm[k].ylign[j].fillSpecSimpleVacancy();
                xzfarm[k].ylign[j].fillSpecSimpleVacancy();
                yzfarm[k].ylign[j].fillSpecSimpleVacancy();

                // fill up bottommost entry in each simple[] with max sized dike
                xyfarm[k].xlign[j].fillSimpleVacancy();
                hzfarm[k].xlign[j].fillSimpleVacancy();
                xzfarm[k].xlign[j].fillSimpleVacancy();
                lcfarm[k].xlign[j].fillSimpleVacancy();
                yzfarm[k].xlign[j].fillSimpleVacancy();
                lcfarm[k].ylign[j].fillSimpleVacancy();

                // For each lign, propagate info upwards int x ligns only
                xyfarm[k].xlign[j].propagateUpSimple();
                hzfarm[k].xlign[j].propagateUpSimple();
                xzfarm[k].xlign[j].propagateUpSimple();
                lcfarm[k].xlign[j].propagateUpSimple();
                yzfarm[k].xlign[j].propagateUpSimple();
                lcfarm[k].ylign[j].propagateUpSimple();

                // propagate info downward
                xyfarm[k].xlign[j].propagateDownSimple();
                hzfarm[k].xlign[j].propagateDownSimple();
                xyfarm[k].xlign[j].maxSimple(neighbor: hzfarm[k].xlign[j])
                xzfarm[k].xlign[j].propagateDownSimple();
                lcfarm[k].xlign[j].propagateDownSimple();
                xzfarm[k].xlign[j].maxSimple(neighbor: lcfarm[k].xlign[j])
                yzfarm[k].xlign[j].propagateDownSimple();
                lcfarm[k].ylign[j].propagateDownSimple();
                yzfarm[k].xlign[j].maxSimple(neighbor: lcfarm[k].ylign[j])
            }
        }
        // copy the simple info to xlign[N]
        for k in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            xyfarm[k].xlign[AdaptiveSkeletonClimber.N].simple = xyfarm[k].xlign[AdaptiveSkeletonClimber.N - 1].simple //, Lign::simplesize);
            xzfarm[k].xlign[AdaptiveSkeletonClimber.N].simple = xzfarm[k].xlign[AdaptiveSkeletonClimber.N - 1].simple //, Lign::simplesize);
            yzfarm[k].xlign[AdaptiveSkeletonClimber.N].simple = yzfarm[k].xlign[AdaptiveSkeletonClimber.N - 1].simple //, Lign::simplesize);
        }
    }


    mutating func buildHighRice() {
        xyfarm.reserveCapacity(AdaptiveSkeletonClimber.N + 1)
        xzfarm.reserveCapacity(AdaptiveSkeletonClimber.N + 1)
        yzfarm.reserveCapacity(AdaptiveSkeletonClimber.N + 1)
        
        xyfarm.removeAll(keepingCapacity: true)
        xzfarm.removeAll(keepingCapacity: true)
        yzfarm.removeAll(keepingCapacity: true)
        
        for i in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            xyfarm.append(Farm(xis: XisQ(), yis: YisQ(), fixdimval: i, block: self)!)
            xzfarm.append(Farm(xis: XisQ(), yis: ZisQ(), fixdimval: i, block: self)!)
            yzfarm.append(Farm(xis: YisQ(), yis: ZisQ(), fixdimval: i, block: self)!)

            xyfarm[i].producePadi(block: self)
            #if DEBUG
            Padi.out2DPadiPS(climber: climber, farm: xyfarm[i], offx: offX, offy: offY, offz: offZ)
            #endif
            xyfarm[i].initSimpleByPadi()
        }
        highricelist = produceHighRice(block: self, farms: xyfarm)
        #if DEBUG
        HighRice.highRiceStatistic(highricelist)
        HighRice.out3DHighRice(climber: climber, farms: xyfarm, highricelist: highricelist, offx: offX, offy: offY, offz: offZ)
        #endif
        // Construct vertical farms
        initSimpleByHighRice()
    }



    mutating func generateTriangle(withnormal : Bool, triangles : inout [Euclid.Polygon]) {

        for i in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            guard i < xyfarm.count else { continue }
            xyfarm[i].producePadi(block: self, constrain: .highrice)
            xzfarm[i].producePadi(block: self, constrain: .highrice)
            yzfarm[i].producePadi(block: self, constrain: .highrice)
            #if DEBUG
            Padi.out2DPadiPS(climber: climber, farm: xyfarm[i], offx: offX, offy: offY, offz: offZ)
            Padi.out2DPadiPS(climber: climber, farm: xzfarm[i], offx: offX, offy: offY, offz: offZ)
            Padi.out2DPadiPS(climber: climber, farm: yzfarm[i], offx: offX, offy: offY, offz: offZ)
            #endif
        }
        for hrice in highricelist {
            // in order to minimize memory requirement, a global edge table from class block is reused for each highrice
            hrice.setupEdgeTable(xyfarm: xyfarm, xzfarm: xzfarm, yzfarm: yzfarm, edge: &Block.edge)
            
            Block.pathcnt.removeAll(keepingCapacity: true)
            hrice.generatePath(path: &Block.path, pathcnt: &Block.pathcnt, edge: &Block.edge)
            if !Block.path.isEmpty {
                // nonzero no of path
                outTriangle(hrice: hrice, path: &Block.path, pathcnt: Block.pathcnt, withnormal: withnormal, triangles: &triangles)
            }
        }
    }

    private func vlerp(_ v1 : Vector, _ v2 : Vector, ratio : Double) -> Vector {
        let recip = 1 - ratio
        return v1 * ratio + v2 * recip
    }

    func outTriangle(hrice : HighRice, path : inout [Int], pathcnt : [Int], withnormal : Bool, triangles : inout [Euclid.Polygon]) {
      //int i, cell[3], k,
        var cell = [Int](repeating: 0, count: 3)
        var ratio = 0.0
        var vidx  = [Int](repeating: 0, count: 3)
        //, segcnt, j, tmp;
      //int finished, searchstart;
//      CHAR side;
//      double ratio;
//      float gradient1[3], gradient2[3], *vv, *nn;
//      float cv1[3], cv2[3], cross[3];
//      double anglethresh, cosanglethresh, thinthresh, fatthresh;
//      static CHAR first=TRUE;
//      static float *vert, *grad;
//      static int elementno;
      
        // atmost 1 edge in each unit square. and there are 6 faces, I use 12 for security
        let elementno = (2 * 6 * AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N + 1)
        var vert : [Vector] = []
        var grad : [Vector] = []
        vert.reserveCapacity(elementno)
        grad.reserveCapacity(elementno)

      // for each node on the path, calculate its vertex location and gradient
        var start = 0
        for pathCount in pathcnt {
            for i in start ..< start + pathCount {
                assert(3 * i <= 3 * elementno, "[Block::OutTriangle]: too little memory allocated for vert and grad\n")
                var side = Dimension.x
                hrice.indexToCoord(idx: &path[i], coord: &cell, xyz: &side)
                vert.append(calVertex(cell: cell, side: side, ratio: &ratio))
                var gradient1 = calFastGradient(cell: cell)
                if (ratio > 0) {
                    // linear interpolated the gradient
                
                    switch(side)
                    {
                    case .x:
                        if (cell[side.rawValue] + offX < climber.G_DataWidth) {
                            cell[side.rawValue] += 1
                        }
                    case .y:
                        if (cell[side.rawValue] + offY < climber.G_DataDepth) {
                            cell[side.rawValue] += 1
                        }
                    case .z:
                        if (cell[side.rawValue] + offZ < climber.G_DataHeight) {
                            cell[side.rawValue] += 1
                        }                                            
                    }
                    let gradient2 = calFastGradient(cell: cell)
                    gradient1 = vlerp(gradient2, gradient1, ratio: ratio)
                }
                gradient1.x *= AdaptiveSkeletonClimber.G_WidthScale_2
                gradient1.y *= AdaptiveSkeletonClimber.G_DepthScale_2
                gradient1.z *= AdaptiveSkeletonClimber.G_HeightScale_2
                
                // normalize the gradient vector
                gradient1 = gradient1.normalized()
                grad.append(gradient1)
            }
            start += pathCount
        }

        // for each disjoint path
        start = 0
        for pathCount in pathcnt {
            var segcnt = pathCount
            vidx[0] = (start - 1) * 3
            var anglethresh = AdaptiveSkeletonClimber.G_AngleThresh
            var cosanglethresh = AdaptiveSkeletonClimber.G_CosAngleThresh // This constraint will be relaxed if no way to improved
            var thinthresh = Block.THINTHRESH // define as constant as a trail
            var fatthresh  = Block.FATTHRESH // cannot be too thin and not too fat
            var idlecnt = 0
            
            // tesellate the polygon into triangles
            while (segcnt >= 3) {
                let searchstart = vidx[0] / 3 + 1 - start
                // find 3 "consecutive" points and make it vertices
                var i = searchstart
                var j = 0
                while j < 3 {
                    let off = modulo(i, pathCount) + start
                    if (path[off] >= 0) {
                        // record the index of vertices
                        vidx[j] = 3 * off
                        j += 1
                    }
                    i = (i >= 2000) ? modulo(i, pathCount) + 1 : i + 1
                }
                idlecnt += 1
                if (idlecnt > segcnt) {
                    // no triangle can be generated using this constraint
                    // **** SERIOUS BUG FOUND HERE ****
                    // anglethresh = MIN(M_PI_2, anglethresh+0.15);
                    // The above original constraint is too tight that will introduce
                    // inifinte loop and halt the program. Pi/2 is changed to Pi.
                    anglethresh = min(Double.pi, anglethresh + 0.15)  // relax the constraint
                    cosanglethresh = cos(anglethresh)
                    thinthresh -= 0.0005     // Also relax the thin triangle constraint
                    fatthresh += 0.0005       // Also relax the fat triangle constraint
                    idlecnt = 1          // reset counter
                }

                var finished = vidx[1]
                // Check for degenerate triangle
                // Degenerate triangle is possible when the isosurface "touch"
                // one or more vertex out of 8 vertex of the cell.
                // If degenerate triangle found, simply ignore it.
                if ((vert[vidx[0]] != vert[vidx[1]]) &&
                    (vert[vidx[0]] != vert[vidx[2]]) &&
                    (vert[vidx[1]] != vert[vidx[2]])) {
                    
                    // To make the vertex direction confirm with the normal direction
                    let cv1 = vert[vidx[2]] - vert[vidx[1]]
                    let cv2 = vert[vidx[0]] - vert[vidx[1]]
                    var cross = cv1.cross(cv2) // cross cv1 x cv2
                    
                    if (cross.dot(grad[vidx[1]]) < 0) {
                        
                        // cross.n[0] make the vertex direction reverse
                        // swap v[0] and v[2], n[0] and n[2]
                        let tmp = vidx[0]
                        vidx[0] = vidx[2]
                        vidx[2] = tmp
                    }

                    if (Block.G_HandleBeauty) {
                        // Find the angle derivation of triangle normal with average gradient normal
                        var avgnorm = grad[vidx[0]] + grad[vidx[1]]
                        avgnorm = grad[vidx[2]] + avgnorm
                        avgnorm = avgnorm * 1.0 / 3.0
                        avgnorm = avgnorm.normalized()
                        cross = cross.normalized()
                        let dp = abs(avgnorm.dot(cross))
                        if (dp < cosanglethresh) {
                            // derivation too large, reject this triangle
                            continue;  // REJECT IT !!!
                        }
                        if (dp < Block.G_mindpvalue) {
                            // see whether there is any improvement in angle derivation
                            Block.G_mindpvalue = dp
                        }
                    }

                    Block.G_Stat_TriangleCnt += 1 // record no of triangle
                    
                    if let triangle = outTriBinary(vertices: vert, normals: grad, indices: vidx, withnormal: withnormal) {
                        triangles.append(triangle)
                    }
                } else {
                    if ((vert[vidx[0]] != vert[vidx[1]])
                        &&  (vert[vidx[2]] != vert[vidx[1]])) {
                        // then v1 is significant and cannot be removed, remove v0 or v2
                        finished = vidx[0]
                    }
                }
                finished /= 3;
                path[finished] = -path[finished] - 1 // marked one vertex as processed
                segcnt -= 1
                idlecnt = 0  // reset the counter
            }
            start += pathCount
        }
    }

    // Output Propietrary triangle binary format
    // This format is not suitable for transfer to and from different machine
    // due to the byte order and size of float may different.
    // <v1.x> <v1.y> <v1.z> <n1.x> <n1.y> <n1.z>
    // <v2.x> <v2.y> <v2.z> <n2.x> <n2.y> <n2.z>
    // <v3.x> <v3.y> <v3.z> <n3.x> <n3.y> <n3.z>  .... all in "float"
    func outTriBinary(vertices : [Vector], normals : [Vector], indices idx : [Int], withnormal : Bool) -> Euclid.Polygon? {
        
        var buffer : [Vertex] = []
        buffer.reserveCapacity(3)
                
        for i in 0 ..< 3 {
            let normal : Vector
            if (withnormal) {
                normal = normals[idx[i]]
            } else {
                normal = Vector.zero
            }
            let v = Vertex(vertices[idx[i]], normal)
            buffer.append(v)
        }
        return Euclid.Polygon(buffer)
    }


    func calVertex(cell : [Int], side : Dimension, ratio : inout Double) -> Vector {
            
        var l = VoxelData(climber: climber)

        let x = cell[Dimension.x.rawValue]
        let y = cell[Dimension.y.rawValue]
        let z = cell[Dimension.z.rawValue]
    
        assert(!(x < 0 || x > AdaptiveSkeletonClimber.N + 1 || y < 0 || y > AdaptiveSkeletonClimber.N + 1 || z < 0 || z > AdaptiveSkeletonClimber.N + 1), "[Block::CalVertex]: IndexCoord map to wrong coordinate\n")
        
        var coord = Vector(Double(offX + x), Double(offY + y), Double(offZ + z))
        // linearly interpolate the vertex position
    
        assert(cell[side.rawValue] <= AdaptiveSkeletonClimber.N, "[Block::OutTriangle]: index out of bound\n")
              
        switch (side) {
        case .x:
            l.reinit(x: -1, y: y, z: z, offx: offX, offy: offY, offz: offZ)
            let x1 = Double(l.value(x))
            let x2 = Double(l.value(x + 1))
            ratio = (AdaptiveSkeletonClimber.G_Threshold - x1) / Double((x2 - x1))
            coord.x += ratio
          
        case .y:
            l.reinit(x: x, y: -1, z: z, offx: offX, offy: offY, offz: offZ)
            let y1 = Double(l.value(y))
            let y2 = Double(l.value(y + 1))
            ratio = (AdaptiveSkeletonClimber.G_Threshold - y1) / Double((y2 - y1))
            coord.y += ratio;
          
        case .z:
            l.reinit(x: x, y: y, z: -1, offx: offX, offy: offY, offz: offZ)
            let z1 = Double(l.value(z))
            let z2 = Double(l.value(z + 1))
            ratio = (AdaptiveSkeletonClimber.G_Threshold - z1) / Double((z2 - z1))
            coord.z += ratio
        }
        
        coord.x *= AdaptiveSkeletonClimber.G_WidthScale
        coord.y *= AdaptiveSkeletonClimber.G_DepthScale
        coord.z *= AdaptiveSkeletonClimber.G_HeightScale
    
        assert(!(coord.x < 0 || coord.y < 0 || coord.z < 0), "invalid coordinate\n")
        return coord
    }


    // The true and exact gradient is not calculated in order to speed up
    // by reducing no of multiplication and division.
    func calFastGradient(cell : [Int]) -> Vector {
        var xl = VoxelData(climber: climber)
        var yl = VoxelData(climber: climber)
        var zl = VoxelData(climber: climber)

        let x = cell[Dimension.x.rawValue] + offX
        let y = cell[Dimension.y.rawValue] + offY
        let z = cell[Dimension.z.rawValue] + offZ
        let xprev = (x == 0) ? 0 : x - 1
        let yprev = (y == 0) ? 0 : y - 1
        let zprev = (z == 0) ? 0 : z - 1
        let xnext = (x == climber.G_DataWidth - 1) ? x : x + 1
        let ynext = (y == climber.G_DataDepth - 1) ? y : y + 1
        let znext = (z == climber.G_DataHeight - 1) ? z : z + 1
        xl.reinit(x: -1, y: y, z: z, offx: 0, offy: 0, offz: 0)
        yl.reinit(x: x, y: -1, z: z, offx: 0, offy: 0, offz: 0)
        zl.reinit(x: x, y: y, z: -1, offx: 0, offy: 0, offz: 0)

        // The correct gradient is calculated in the following manner
        // gradient[Dimension.x.rawValue] = (xl.Value(xnext) - xl.Value(xprev))/2.0 * G_WidthScale;
        // gradient[Dimension.y.rawValue] = (yl.Value(ynext) - yl.Value(yprev))/2.0 * G_DepthScale;
        // gradient[Dimension.z.rawValue] = (zl.Value(znext) - zl.Value(zprev))/2.0 * G_HeightScale;

        // Instead an inexact gradient is calculated
        return Vector(
            Double(xl.value(xnext) - xl.value(xprev)),
            Double(yl.value(ynext) - yl.value(yprev)),
            Double(zl.value(znext) - zl.value(zprev))
        )
    }


    // Share simple[] info among the neighbor block
    func communicateSimple(bottom : Block?, top : Block?, nearxz : Block?, farxz : Block?, nearyz : Block?, faryz : Block?) {

          // a neigbor block is valid if it exists and it is not empty
        let validface = [
            bottom != nil && !bottom!.isEmptyQ(),
            top != nil    && !top!.isEmptyQ(),
            nearxz != nil && !nearxz!.isEmptyQ(),
            farxz != nil  && !farxz!.isEmptyQ(),
            nearyz != nil && !nearyz!.isEmptyQ(),
            faryz != nil  && !faryz!.isEmptyQ()
        ]
        
        for face in 0 ..< 6 {
            if (validface[face]) {
                for j in 0 ..< AdaptiveSkeletonClimber.N + 1 {
                    let my : Int
                    let nb : Int
                    var myFarm : [Farm]
                    let nbFarm : [Farm]
                    
                    switch (face) {
                    case HighRiceSide.bottom.rawValue:
                            myFarm = self.xyfarm
                            nbFarm = bottom!.xyfarm
                            my = 0 // xyfarm[0].xlign[j].simple;
                            // myy = xyfarm[0].ylign[j].simple;
                            nb = AdaptiveSkeletonClimber.N // bottom!.xyfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            //nby = bottom!.xyfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                            
                        case HighRiceSide.top.rawValue:
                            myFarm = self.xyfarm
                            nbFarm = top!.xyfarm
                            my = AdaptiveSkeletonClimber.N // xyfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            //myy = xyfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                            nb = 0 // top!.xyfarm[0].xlign[j].simple;
                            // nby = top!.xyfarm[0].ylign[j].simple;
                        
                        case HighRiceSide.nearXZ.rawValue:
                            myFarm = self.xzfarm
                            nbFarm = nearxz!.xzfarm
                            
                            my = 0 // xzfarm[0].xlign[j].simple;
                            //myy = xzfarm[0].ylign[j].simple;
                            nb = AdaptiveSkeletonClimber.N // nearxz!.xzfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            //nby = nearxz!.xzfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                        
                        case HighRiceSide.farXZ.rawValue:
                            myFarm = self.xzfarm
                            nbFarm = farxz!.xzfarm
                            
                            my = AdaptiveSkeletonClimber.N // xzfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            // myy = xzfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                            nb = 0 // farxz!.xzfarm[0].xlign[j].simple;
                            // nby = farxz!.xzfarm[0].ylign[j].simple;
                        
                        case HighRiceSide.nearYZ.rawValue:
                            myFarm = self.yzfarm
                            nbFarm = nearyz!.yzfarm
                            
                            my = 0 // yzfarm[0].xlign[j].simple;
                            //myy = yzfarm[0].ylign[j].simple;
                            nb = AdaptiveSkeletonClimber.N // nearyz!.yzfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            //nby = nearyz!.yzfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                        
                        case HighRiceSide.farYZ.rawValue:
                            myFarm = self.yzfarm
                            nbFarm = faryz!.yzfarm
                            
                            my = AdaptiveSkeletonClimber.N // yzfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            // myy = yzfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                            nb = 0 // faryz!.yzfarm[0].xlign[j].simple;
                            //nby = faryz!.yzfarm[0].ylign[j].simple;
                        
                        default:
                            return
                    }
                    
                    for i in 0 ..< AdaptiveSkeletonClimber.SIZE { //} ; i++, myx++, myy++, nbx++, nby++)
                        
                        guard my < myFarm.count else { continue }
                        myFarm[my].xlign[j].simple[i] = max(myFarm[my].xlign[j].simple[i], nbFarm[nb].xlign[j].simple[i])
                        myFarm[my].ylign[j].simple[i] = max(myFarm[my].ylign[j].simple[i], nbFarm[nb].ylign[j].simple[i])
                    }
                }
            }
        }
    }
}
