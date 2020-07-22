//
//  Block.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 09/07/2020.
//

import Foundation
import Euclid

func DISPLAYTREE(_ a : [Int], offset : Int = 0) {
    for di in 0 ... AdaptiveSkeletonClimber.NLEVEL {
        for dj in 0 ..< (1 << di) {
            print("%d ", Int(a[offset + (1 << di) + dj]))
        }
    }
    print("\n")
}

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
        print(" %d x %d x [%d,%d]\n", h.dike[0], h.dike[1], h.bottom, h)
    }

    public let blockData : [CUnsignedChar]
    public let dataDimX : Int
    public let dataDimY : Int
    public let dataDimZ : Int
    
    public var OffX : Int = 0
    public var OffY : Int = 0
    public var OffZ : Int = 0
    
    public var highricelist = DoublyLinkedList<HighRice>()
    public var xyfarm = [Farm](repeating: Farm(), count: AdaptiveSkeletonClimber.N + 1)
    public var xzfarm = [Farm](repeating: Farm(), count: AdaptiveSkeletonClimber.N + 1)
    public var yzfarm = [Farm](repeating: Farm(), count: AdaptiveSkeletonClimber.N + 1)
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
                                        
    
    private func XisQ() -> CChar {
        return CChar(EXYZis & 0x03)
    }
    private func YisQ() -> CChar {
        return CChar((EXYZis>>2) & 0x03)
    }
    private func ZisQ() -> CChar {
        return CChar((EXYZis>>4) & 0x03)
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
    
    public init(blockData : [CUnsignedChar], dataDimX : Int, dataDimY : Int, dataDimZ : Int) {
        self.blockData = blockData
        self.dataDimX = dataDimX
        self.dataDimY = dataDimY
        self.dataDimZ = dataDimZ
    }
    
    public mutating func initialize(xis : Dimension, yis : Dimension, zis : Dimension,
                    offx : Int, offy : Int, offz : Int) {
        
        
        OffX = offx
        OffY = offy
        OffZ = offz
        EXYZis = 0
        setXis(xis)
        setYis(yis)
        setZis(zis)
        highricelist = DoublyLinkedList<HighRice>()

        // init x y z occ[] and ver[]
        var nonempty : CChar = 0
        let mydata = VoxelData(blockData, -1, 0, 0, OffX, OffY, OffZ)
        for j in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            for i in 0 ..< AdaptiveSkeletonClimber.N + 1 {
                let pos = (j * (AdaptiveSkeletonClimber.N + 1) + i) * AdaptiveSkeletonClimber.SIZE
                mydata.ReInit(blockData, -1, i, j, OffX, OffY, OffZ)
                Initocc(mydata, &xocc, pos)
                Initver(occ: xocc, ver: &xver, offset: pos)
                mydata.ReInit(blockData, i, -1, j, OffX, OffY, OffZ)
                Initocc(mydata, &yocc, pos)
                Initver(occ: yocc, ver: &yver, offset: pos)
                mydata.ReInit(blockData, i, j, -1, OffX, OffY, OffZ)
                Initocc(mydata, &zocc, pos)
                Initver(occ: zocc, ver: &zver, offset: pos)
                nonempty |= (xocc[pos+1] | yocc[pos+1] | zocc[pos+1])
            }
        }
        if (nonempty > 0) {
            setEmpty()
        } else {
            Block.G_NonEmptyBlockCnt += 1
        }
    }


    func Initocc(data : VoxelData, occ : inout [CChar], offset: Int) {
      
        // Construct bottom level of the binary tree
        for var i in 0 ..< AdaptiveSkeletonClimber.N {
            let d1 = data[i]     // This is not because the cost of dereferencing,
            let d2 = data[i + 1] // but also operator[] is actually a function.
            occ[offset + i + AdaptiveSkeletonClimber.N] = ((d1 << 1) | (~d1 & 0x01)) & (((~d2 & 0x01) << 1) | d2);
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

    mutating func produceHighRice(block: Block, farms : [Farm]) -> DoublyLinkedList<HighRice> {
    
        var xydike : [Int]
        var holdercnt : Int
        var competecnt : Int
        var currhighrice : HighRice? = nil
        var holder = [HighRice?](repeating: nil, count: AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N)
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
            var go_on = slab[j].firstPadi(&xydike)
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
                holdercnt = 0
                currhighrice = HighRice(x: x, y: y, b: j, t: jj)
                repeat {
                    // for each highrice which is broken up by overlapped highrice
                    if (holdercnt > 0) { // consider clipped highrice
                      holdercnt -= 1   // decrement counter
                      currhighrice = holder[holdercnt] // pick one element from array
                      holder[holdercnt] = nil
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
                            untagSlab(competitorK)
                            highricelist.remove(where: { $0 === competitorK })
                            competitor[k] = nil
                      
                        } else {
                            // only partial overlaid, break the current highrice
                      
            #if DEBUG
                            HIGHRICEDIM(s: "before: break current highrice", h: currhighrice!)
                            HIGHRICEDIM(s: "clipped by highrice", h: competitorK)
            #endif
                            currhighrice!.clipBy(competitorK, holder, holdercnt)
                            currhighrice = nil
                            highricesuccess = false
                            // no need to continue, since the clipped portion have to go through the whole test
                            break
                        }
                    }

                    if (highricesuccess) {
                        // Tag those occupied region
                        TagSlab(currhighrice!)
                        // Insert the current padi into the doubly linked list
                        highricelist.append(currhighrice!)
                        #if DEBUG
                        HIGHRICEDIM(s: "current highrice born", h: currhighrice!)
                        #endif
                    }
                } while (holdercnt > 0)
                go_on = slab[j].nextPadi(&xydike)
            }
        }
        
        return highricelist
    }



    mutating func initSimpleByHighRice() {
                    
        // lcfarm is localfarm, its xlign is used as temporary
        // array for xzfarm[].xlign[] and its ylign is used as
        // temporary for yzfarm[].xlign[].
        var lcfarm = [Farm](repeating: Farm(), count: AdaptiveSkeletonClimber.N+1)
        var hzfarm = [Farm](repeating: Farm(), count: AdaptiveSkeletonClimber.N+1)

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
        for i in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            xyfarm[i].initialize(xis: XisQ(), yis: YisQ(), fixdimval: i, xocc: xocc, yocc: yocc, xver: xver, yver: yver);
            xzfarm[i].initialize(XisQ(), ZisQ(), i, xocc, zocc, xver, zver);
            yzfarm[i].initialize(YisQ(), ZisQ(), i, yocc, zocc, yver, zver);

            xyfarm[i].producePadi(self)
            #if DEBUG
            out2DPadiPS(data: blockData, farm: xyfarm[i], offx: OffX, offy: OffY, offz: OffZ, datadimx: dataDimX, datadimy: dataDimY, datadimz: dataDimZ)
            #endif
            xyfarm[i].initSimpleByPadi()
        }
        highricelist = produceHighRice(block: self, farms: xyfarm)
        #if DEBUG
        HighRiceStatistic(highricelist)
        Out3DHighRice(BlockData, xyfarm, highricelist, OffX, OffY, OffZ, dataDimX, dataDimY, dataDimZ)
        #endif
        // Construct vertical farms
        initSimpleByHighRice()
    }



    func generateTriangle(withnormal : Bool, file : inout File) {

        for i in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            xyfarm[i].producePadi(block: self, constrain: Block.PP_HRICECONSTR);
            xzfarm[i].producePadi(block: self, constrain: Block.PP_HRICECONSTR);
            yzfarm[i].producePadi(block: self, constrain: Block.PP_HRICECONSTR);
            #if DEBUG
            Padi.out2DPadiPS(Data, &(xyfarm[i]), OffX, OffY, OffZ, dataDimX, dataDimY, dataDimZ)
            Padi.out2DPadiPS(Data, &(xzfarm[i]), OffX, OffY, OffZ, dataDimX, dataDimY, dataDimZ)
            Padi.out2DPadiPS(Data, &(yzfarm[i]), OffX, OffY, OffZ, dataDimX, dataDimY, dataDimZ)
            #endif
        }
        for hrice in highricelist {
            // in order to minimize memory requirement, a global edge table from class block is reused for each highrice
            hrice.setupEdgeTable(xyfarm: xyfarm, xzfarm: xzfarm, yzfarm: yzfarm, edge: &Block.edge)
            
            Block.pathcnt.removeAll(keepingCapacity: true)
            hrice.generatePath(path: &Block.path, pathcnt: &Block.pathcnt, edge: &Block.edge)
            if !Block.path.isEmpty {
                // nonzero no of path
                outTriangle(hrice, &Block.path, Block.pathcnt, pathno, withnormal, file)
            }
        }
    }



    func outTriangle(hrice : HighRice, path : inout [Int], pathcnt : [Int],
                     pathno : Int, withnormal : Bool, file : inout File) {
      //int i, cell[3], k,
        var cell = [Int](repeating: 0, count: 3)
        var ratio = 0.0
        var gradient1 = Vector.zero
        var gradient2 = Vector.zero
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
        var vert = [Vector](repeating: Vector.zero, count: elementno)
        var grad = [Vector](repeating: Vector.zero, count: elementno)

      // for each node on the path, calculate its vertex location and gradient
        var start = 0
        var vv = 0
        for k in 0 ..< pathno {
            for i in start ..< start + pathcnt[k] {
                assert(3 * i <= 3 * elementno, "[Block::OutTriangle]: too little memory allocated for vert and grad\n")
                var side = Dimension.x
                hrice.indexToCoord(idx: &path[i], coord: &cell, xyz: &side)
                calVertex(coord: &vert[vv], cell: cell, side: side, ratio: &ratio)
                calFastGradient(gradient: &gradient1, cell: cell)
                if (ratio > 0) {
                    // linear interpolated the gradient
                
                    switch(side)
                    {
                    case .x:
                        if (cell[side.rawValue] + OffX < dataDimX) {
                            cell[side.rawValue] += 1
                        }
                    case .y:
                        if (cell[side.rawValue] + OffY < dataDimY) {
                            cell[side.rawValue] += 1
                        }
                    case .z:
                        if (cell[side.rawValue] + OffZ < dataDimZ) {
                            cell[side.rawValue] += 1
                        }
                        
                    default:
                        break
                    }
                    calFastGradient(gradient: &gradient2, cell: cell)
                    vlerp(gradient2, gradient1, ratio, gradient1)
                }
                gradient1.x *= AdaptiveSkeletonClimber.G_WidthScale_2
                gradient1.y *= AdaptiveSkeletonClimber.G_DepthScale_2
                gradient1.z *= AdaptiveSkeletonClimber.G_HeightScale_2
                
                // normalize the gradient vector
                gradient1 = gradient1.normalized()
                grad[vv] = gradient1
                
                vv += 1
            }
            start += pathcnt[k]
        }

        // for each disjoint path
        start = 0
        for k in 0 ..< pathno {
            var segcnt = pathcnt[k]
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
                    let off = i % pathcnt[k] + start
                    if (path[off] >= 0) {
                        // record the index of vertices
                        vidx[j] = 3 * off
                        j += 1
                    }
                    i = (i >= 2000) ? i % pathcnt[k] + 1 : i + 1
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
                        var dp = abs(avgnorm.dot(cross))
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

                    outTriBinary(vert, grad, vidx, withnormal, file)
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
            start += pathcnt[k]
        }
    }

    // Output Propietrary triangle binary format
    // This format is not suitable for transfer to and from different machine
    // due to the byte order and size of float may different.
    // <v1.x> <v1.y> <v1.z> <n1.x> <n1.y> <n1.z>
    // <v2.x> <v2.y> <v2.z> <n2.x> <n2.y> <n2.z>
    // <v3.x> <v3.y> <v3.z> <n3.x> <n3.y> <n3.z>  .... all in "float"
    func outTriBinary(v : [Float], n : [Float], idx : [Int], withnormal : Bool, file : inout File) {
        
        var buffer = [Float](repeating: 0.0, count: 18)
        var cnt = 0
        for i in 0 ..< 3 {
            for j in 0 ..< 3 {
                buffer[cnt] = v[idx[i] + j]
                cnt += 1
            }
        
            for j in 0 ..< 3 {
                if (withnormal) {
                    buffer[cnt] = n[idx[i] + j]
                } else {
                    // must fill with some value if no normal
                    buffer[cnt] = 0
                }
                cnt += 1
            }
        }
        cp_fwrite(buffer, sizeof(float), 18, file);
    }


    func calVertex(coord : inout Vector, cell : [Int], side : Dimension, ratio : inout Double) {
            
        let l = Data(BlockData, -1,  0,  0, OffX, OffY, OffZ, dataDimX, dataDimY, dataDimZ)

        let x = cell[Dimension.x.rawValue]
        let y = cell[Dimension.y.rawValue]
        let z = cell[Dimension.z.rawValue]
    
        assert(!(x < 0 || x > AdaptiveSkeletonClimber.N + 1 || y < 0 || y > AdaptiveSkeletonClimber.N + 1 || z < 0 || z > AdaptiveSkeletonClimber.N + 1), "[Block::CalVertex]: IndexCoord map to wrong coordinate\n")
        
        coord.x = Double(OffX + x)
        coord.y = Double(OffY + y)
        coord.z = Double(OffZ + z)
        // linearly interpolate the vertex position
    
        assert(cell[side.rawValue] <= AdaptiveSkeletonClimber.N, "[Block::OutTriangle]: index out of bound\n")
              
        switch (side) {
        case .x:
            l.reInit(BlockData, -1, y, z, OffX, OffY, OffZ, BlockData.DataDimX, BlockData.DataDimY, BlockData.DataDimZ);
            let x1 = l.Value(x)
            let x2 = l.Value(x+1)
            ratio = Double(AdaptiveSkeletonClimber.G_Threshold - x1) / (x2 - x1)
            coord.x += ratio
          
        case .y:
            l.reInit(BlockData, x, -1, z, OffX, OffY, OffZ, BlockData.DataDimX, BlockData.DataDimY, BlockData.DataDimZ);
            let y1 = l.Value(y)
            let y2 = l.Value(y + 1)
            ratio = Double(AdaptiveSkeletonClimber.G_Threshold - y1) / (y2 - y1)
            coord.y += ratio;
          
        case .z:
            l.reInit(BlockData, x, y, -1, OffX, OffY, OffZ, BlockData.DataDimX, BlockData.DataDimY, BlockData.DataDimZ);
            let z1 = l.Value(z)
            let z2 = l.Value(z + 1)
            ratio = Double(AdaptiveSkeletonClimber.G_Threshold - z1) / (z2 - z1)
            coord.z += ratio
        }
        
        coord.x *= AdaptiveSkeletonClimber.G_WidthScale
        coord.y *= AdaptiveSkeletonClimber.G_DepthScale
        coord.z *= AdaptiveSkeletonClimber.G_HeightScale
    
        assert(!(coord.x < 0 || coord.y < 0 || coord.z < 0), "invalid coordinate\n")
    
    }


    // The true and exact gradient is not calculated in order to speed up
    // by reducing no of multiplication and division.
    func calFastGradient(gradient : inout Vector, cell : [Int]) {
        let xl = Data(BlockData, -1,  0,  0, OffX, OffY, OffZ, dataDimX, dataDimY, dataDimZ)
        let yl = Data(BlockData, -1,  0,  0, OffX, OffY, OffZ, dataDimX, dataDimY, dataDimZ)
        let zl = Data(BlockData, -1,  0,  0, OffX, OffY, OffZ, dataDimX, dataDimY, dataDimZ)

        let x = cell[Farm.XDIM] + OffX
        let y = cell[Farm.YDIM] + OffY
        let z = cell[Farm.ZDIM] + OffZ
        let xprev = (x == 0) ? 0 : x - 1
        let yprev = (y == 0) ? 0 : y - 1
        let zprev = (z == 0) ? 0 : z - 1
        let xnext = (x == dataDimX - 1) ? x : x + 1
        let ynext = (y == dataDimY - 1) ? y : y + 1
        let znext = (z == dataDimZ - 1) ? z : z + 1
        xl.reInit(BlockData, -1, y, z, 0, 0, 0, dataDimX, dataDimY, dataDimZ)
        yl.reInit(BlockData, x, -1, z, 0, 0, 0, dataDimX, dataDimY, dataDimZ)
        zl.reInit(BlockData, x, y, -1, 0, 0, 0, dataDimX, dataDimY, dataDimZ)

        // The correct gradient is calculated in the following manner
        // gradient[XDIM] = (xl.Value(xnext) - xl.Value(xprev))/2.0 * G_WidthScale;
        // gradient[YDIM] = (yl.Value(ynext) - yl.Value(yprev))/2.0 * G_DepthScale;
        // gradient[ZDIM] = (zl.Value(znext) - zl.Value(zprev))/2.0 * G_HeightScale;

        // Instead an inexact gradient is calculated
        gradient.x = xl.Value(xnext) - xl.Value(xprev)
        gradient.y = yl.Value(ynext) - yl.Value(yprev)
        gradient.z = zl.Value(znext) - zl.Value(zprev)
    }


    // Share simple[] info among the neighbor block
    func communicateSimple(bottom : Block?, top : Block?, nearxz : Block?, farxz : Block?, nearyz : Block?, faryz : Block?) {

          // a neigbor block is valid if it exists and it is not empty
        let validface = [
            bottom != nil && !bottom!.emptyQ(),
            top != nil    && !top!.emptyQ(),
            nearxz != nil && !nearxz!.emptyQ(),
            farxz != nil  && !farxz!.emptyQ(),
            nearyz != nil && !nearyz!.emptyQ(),
            faryz != nil  && !faryz!.emptyQ()
        ]
        
        let HR_BOTTOM = 0
        let HR_TOP = 1
        let HR_NEARXZ = 2
        let HR_FARXZ = 3
        let HR_NEARYZ = 4
        let HR_FARYZ = 5
        
        for face in 0 ..< 6 {
            if (validface[face]) {
                for j in 0 ..< AdaptiveSkeletonClimber.N + 1 {
                    let my : Int
                    let nb : Int
                    let myFarm : [Farm]
                    let nbFarm : [Farm]
                    
                    switch (face) {
                        case HR_BOTTOM:
                            myFarm = self.xyfarm
                            nbFarm = bottom!.xyfarm
                            my = 0 // xyfarm[0].xlign[j].simple;
                            // myy = xyfarm[0].ylign[j].simple;
                            nb = AdaptiveSkeletonClimber.N // bottom!.xyfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            //nby = bottom!.xyfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                            
                        case HR_TOP:
                            myFarm = self.xyfarm
                            nbFarm = top!.xyfarm
                            my = AdaptiveSkeletonClimber.N // xyfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            //myy = xyfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                            nb = 0 // top!.xyfarm[0].xlign[j].simple;
                            // nby = top!.xyfarm[0].ylign[j].simple;
                        
                        case HR_NEARXZ:
                            myFarm = self.xzfarm
                            nbFarm = nearxz!.xzfarm
                            
                            my = 0 // xzfarm[0].xlign[j].simple;
                            //myy = xzfarm[0].ylign[j].simple;
                            nb = AdaptiveSkeletonClimber.N // nearxz!.xzfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            //nby = nearxz!.xzfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                        
                        case HR_FARXZ:
                            myFarm = self.xzfarm
                            nbFarm = farxz!.xzfarm
                            
                            my = AdaptiveSkeletonClimber.N // xzfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            // myy = xzfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                            nb = 0 // farxz!.xzfarm[0].xlign[j].simple;
                            // nby = farxz!.xzfarm[0].ylign[j].simple;
                        
                        case HR_NEARYZ:
                            myFarm = self.yzfarm
                            nbFarm = nearyz!.yzfarm
                            
                            my = 0 // yzfarm[0].xlign[j].simple;
                            //myy = yzfarm[0].ylign[j].simple;
                            nb = AdaptiveSkeletonClimber.N // nearyz!.yzfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            //nby = nearyz!.yzfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                        
                        case HR_FARYZ:
                            myFarm = self.yzfarm
                            nbFarm = faryz!.yzfarm
                            
                            my = AdaptiveSkeletonClimber.N // yzfarm[AdaptiveSkeletonClimber.N].xlign[j].simple;
                            // myy = yzfarm[AdaptiveSkeletonClimber.N].ylign[j].simple;
                            nb = 0 // faryz!.yzfarm[0].xlign[j].simple;
                            //nby = faryz!.yzfarm[0].ylign[j].simple;
                        
                        default:
                            break
                    }
                    
                    for i in 0 ..< AdaptiveSkeletonClimber.SIZE { //} ; i++, myx++, myy++, nbx++, nby++)
                        
                        myFarm[my].xlign[j].simple = max(myFarm[my].xlign[j].simple, nbFarm[nb].xlign[j].simple)
                        myFarm[my].ylign[j].simple = max(myFarm[my].ylign[j].simple, nbFarm[nb].ylign[j].simple)
                    }
                }
            }
        }
    }
}
