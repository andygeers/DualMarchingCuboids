//
//  Padi.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 11/07/2020.
//

import Foundation

// Label of sides of a padi
enum PadiSide : Int {
    case right = 0      //      1
    case top = 1        //   +----+
    case left = 2       // 2 |    | 0
    case bottom = 3     //   +----+
    case invalid        //      3
}

enum PadiConstraint {
    case none
    case padi
    case highrice
}

class Padi {
    static var edgetable = [[PadiSide]](repeating: [PadiSide](repeating: .invalid, count: 4), count: 256)
    
    static func PadiInitEdgeTable() {
                
        // List all 14 cases, 2 null cases
        edgetable[0x81][0] = .bottom; edgetable[0x81][1] = .right;
        
        edgetable[0x60][0] = .right;  edgetable[0x60][1] = .top;
        
        edgetable[0x21][0] = .bottom; edgetable[0x21][1] = .top;
        
        edgetable[0x18][0] = .top;    edgetable[0x18][1] = .left;
        
        edgetable[0x99][0] = .top;    edgetable[0x99][1] = .left;
        edgetable[0x99][2] = .bottom; edgetable[0x99][3] = .right;
        
        edgetable[0x48][0] = .right;  edgetable[0x48][1] = .left;
        
        edgetable[0x09][0] = .bottom; edgetable[0x09][1] = .left;
        
        edgetable[0x06][0] = .left;   edgetable[0x06][1] = .bottom;
        
        edgetable[0x84][0] = .left;   edgetable[0x84][1] = .right;
        
        edgetable[0x66][0] = .right;  edgetable[0x66][1] = .top;
        edgetable[0x66][2] = .left;   edgetable[0x66][3] = .bottom;
        
        edgetable[0x24][0] = .left;   edgetable[0x24][1] = .top;
        
        edgetable[0x12][0] = .top;    edgetable[0x12][1] = .bottom;
        
        edgetable[0x90][0] = .top;    edgetable[0x90][1] = .right;
        
        edgetable[0x42][0] = .right;  edgetable[0x42][1] = .bottom;
    }
    
    var lignavail : Bool = false  // indicate whether lign info is avialable
    var occ : [CChar]
    var lign : [Lign]
    var lookupidx : Int
    var dike : [Int]
    
    // hold padi in a doubly linked list
    var next : Padi?
    var previous : Padi?
    
    internal init(climber: AdaptiveSkeletonClimber, xdike : Int, ydike : Int, farm : Farm?, block : Block?) {
    
        assert(!(xdike < 1 || xdike >= AdaptiveSkeletonClimber.SIZE || ydike < 1 || ydike >= AdaptiveSkeletonClimber.SIZE), "[Padi::Init]: invalid input valid\n")
            
        dike = [
            ydike, //right
            xdike, //top
            ydike, //left
            xdike  //bottom
        ]

        guard let theFarm = farm else { return }
        
        lignavail = true
        
        self.lign = [
            theFarm.ylign[Dike.end(xdike)],   //right
            theFarm.xlign[Dike.end(ydike)],   //top
            theFarm.ylign[Dike.start(xdike)], //left
            theFarm.xlign[Dike.start(ydike)]  //bottom
        ]
        
        occ = []
        occ.reserveCapacity(4)
        for i in 0 ..< 4 {
            occ.append(lign[i].occ(dike[i]))
        }
        // reverse value in .top.rawValue and .left.rawValue ie. 01 -> 10, 10 -> 01
        for i in 1 ..< 3 {
            occ[i] = (occ[i] & 1) << 1 | (occ[i] & 2) >> 1
        }

    
        lookupidx = 0;
        for i in 0 ..< 4 {
            lookupidx = (lookupidx << 2) | (3 & (Int(occ[i])))
        }
        if let theBlock = block, (AdaptiveSkeletonClimber.G_HandleAmbiguity && (lookupidx == 0x99 || lookupidx == 0x66)) {
            
            // ambiguous cases
            resolveAmbiguity(climber: climber, xdike: xdike, ydike: ydike, farm: theFarm, block: theBlock)

        }
 
    }
    
    func resolveAmbiguity(climber: AdaptiveSkeletonClimber, xdike : Int, ydike : Int, farm : Farm, block : Block) {
        // sample the centre data
    
        let xmidpt = (Dike.start(xdike) + Dike.end(xdike)) >> 1  // round down
        let ymidpt = (Dike.start(ydike) + Dike.end(ydike)) >> 1
        let xis = farm.XisV()
        let yis = farm.YisV()
        let xodd = Dike.length(xdike) & 1 > 0
        let yodd = Dike.length(ydike) & 1 > 0
        // get bl and br
        var dim = [Int](repeating: -1, count: 3)
        dim[farm.fixDimV().rawValue] = farm.fixDimValV()
        dim[xis.rawValue] = -1
        dim[yis.rawValue] = ymidpt
        var data = VoxelData(climber: climber, x: dim[0], y: dim[1], z: dim[2],
                             offx: block.offX, offy: block.offY, offz: block.offZ)
        let bl = Double(data.value(xmidpt))
        let br = (xodd) ? Double(data.value(xmidpt + 1)) : bl
        
        // value at four corner of the unit square
        let tl : Double
        let tr : Double
        if (!yodd) {
            tl = bl
            tr = br
        } else {
            dim[yis.rawValue] = ymidpt + 1
            data.reinit(x: dim[0], y: dim[1], z: dim[2], offx: block.offX, offy: block.offY, offz: block.offZ)
            tl = Double(data.value(xmidpt))
            tr = (xodd) ? Double(data.value(xmidpt + 1)) : tl
        }
        // sample the centre
        let sample = (tl + tr + bl + br) / 4.0
        if (sample >= AdaptiveSkeletonClimber.G_Threshold) {
            if (lookupidx == 0x99) {
                lookupidx = 0x66;
            } else {
                // lookupidx == 0x66
                lookupidx = 0x99;
            }
        }
    }

    func GetCrossPt(side : PadiSide, x : inout Double, y : inout Double, spacing : Double) {
    
        assert(spacing >= 0, "[Padi:GetGrossPt]: invalid input value\n");
            
        guard lignavail else { return }
        
        switch (side)
        {
        case .right:
            x = Double(Dike.end(dike[PadiSide.bottom.rawValue])) * spacing
            y = Double(Dike.start(lign[side.rawValue].ver(dike[side.rawValue]))) * spacing + spacing / 2.0
                     
        case .left:
            x = Double(Dike.start(dike[PadiSide.bottom.rawValue])) * spacing
            y = Double(Dike.start(lign[side.rawValue].ver(dike[side.rawValue]))) * spacing + spacing / 2.0
            
        case .top:
            x = Double(Dike.start(lign[side.rawValue].ver(dike[side.rawValue]))) * spacing + spacing / 2.0
            y = Double(Dike.end(dike[PadiSide.left.rawValue])) * spacing
            
        case .bottom:
            x = Double(Dike.start(lign[side.rawValue].ver(dike[side.rawValue]))) * spacing + spacing / 2.0
            y = Double(Dike.start(dike[PadiSide.left.rawValue])) * spacing
            
        default:
            print("[GetCrossPt]: input side is invalid\n")
        }

        #if DEBUG
        if (x < 0 || y < 0) {
            print("[Padi::GetCrossPt]:padi %d x %d\n", dike[PadiSide.bottom.rawValue], dike[PadiSide.left.rawValue])
            print("[Err]:side=%d x=%f y=%f dike[side]=%d start=%d\n", side, x, y, dike[side.rawValue], Dike.start(lign[side.rawValue].ver(dike[side.rawValue])) )
        }
        #endif
    }


    // DEBUG function to visualize the 2D edges formed
    // It output PostScript statements. The callers must provide suitable
    // header of the ps file before calling this function
    func draw2D(spacing : Double, offset : Double) {
        assert(!(spacing<0 || offset<0), "[Padi::Draw2D]: invalid input value\n")
        
        guard lignavail else { return }
      
        // draw the padi box
        var x0 = Double(Dike.start(dike[PadiSide.bottom.rawValue])) * spacing + offset;
        var y0 = Double(Dike.start(dike[PadiSide.left.rawValue])) * spacing + offset;
        var x1 = Double(Dike.end(dike[PadiSide.bottom.rawValue])) * spacing - offset;
        var y1 = Double(Dike.end(dike[PadiSide.right.rawValue])) * spacing - offset;
        print("1 setlinewidth\nnewpath %f %f moveto %f %f lineto %f %f lineto %f %f lineto %f %f lineto stroke  closepath\n",
               x0, y0, x1, y0, x1, y1, x0, y1, x0, y0);

      // Draw edges by looking up the edge table.
        for i in stride(from: 0, to: 3, by: 2) {
            let k = Padi.edgetable[Int(lookupidx)][i]
            let l = Padi.edgetable[Int(lookupidx)][i + 1]
            if (k != .invalid && l != .invalid) {
                GetCrossPt(side: k, x: &x0, y: &y0, spacing: spacing);
                GetCrossPt(side: l, x: &x1, y: &y1, spacing: spacing);
                print("2 setlinewidth\nnewpath %f %f moveto %f %f lineto stroke closepath\n",
                      x0, y0, x1, y1);
            }
        }
    }
    
    func genEdge(edgearr : inout [PadiSide]) {
    
        guard lignavail else {
            print("[PAdi::GenEdge]: no lign info avail to gen edge\n")
            return
        }
        
        // Draw edges by looking up the edge table.
        for i in stride(from: 0, to: 3, by: 2) {
            let k = Padi.edgetable[lookupidx][i]
            let l = Padi.edgetable[lookupidx][i + 1]
            if (k != .invalid && l != .invalid) {
                edgearr.append(k)
                edgearr.append(l)                
            }
        }
    }

    // test whether the input padi enclose this
    // An optimized version can be done by >> the
    func enclosedByQ(_ encloser : Padi) -> Bool {
    
        if (encloser.dike[PadiSide.top.rawValue] > dike[PadiSide.top.rawValue] || encloser.dike[PadiSide.left.rawValue] > dike[PadiSide.left.rawValue]) {
            // since this is impossible for encloser
            return false
        }
        // check enclosure along x
        if ((dike[PadiSide.top.rawValue] >> (Dike.level(dike[PadiSide.top.rawValue]) - Dike.level(encloser.dike[PadiSide.top.rawValue]))) != encloser.dike[PadiSide.top.rawValue]) {
            return false
        }
        // check enclosure along y
        if ((dike[PadiSide.left.rawValue] >> (Dike.level(dike[PadiSide.left.rawValue]) - Dike.level(encloser.dike[PadiSide.left.rawValue]))) != encloser.dike[PadiSide.left.rawValue]) {
            return false
        }
        return true
    }


    // test whether the input padi overlap with this one
    func overlapQ(padi : Padi) -> Bool {
    
        for i in PadiSide.right.rawValue ... PadiSide.top.rawValue {
            // 1st round: check along y
            // 2nd round: check along x
            // check along x direction
            let large : Int
            let small : Int
            if (padi.dike[i] > dike[i]) {
                large = dike[i]
                small = padi.dike[i]
                
            } else {
                large = padi.dike[i]
                small = dike[i];
            }
            // due to the binary restriction, overlap occur only enclosure occur along x and y direction
            if ((small >> (Dike.level(small) - Dike.level(large))) != large) {
                // check enclosure along x or y
                return false
            }
        }
        return true
    }



    // Due to the scheme of dike formation. Two padi cannot overlap in
    // a very tricky form. If one padi is clipped by another one,
    // there are at most two portions of the original padi will
    // Notice this function ASSUME only simple clipping (previous criteria).
    // It also ASSUME no complete enclosure of each another
    // The most general case this function can handle is:
    //        +---+
    //        |   |
    //        |   |
    //  +-----+---+------+
    //  |     |   |      |
    //  +-----+---+------+
    //        |   |
    //        |   |
    //        +---+
    // Return value:
    // "this" will not not affected
    // 1) holder    The clipped padi will be appended into holder array.
    // 2) cnt       The amount of element in holder array.
    func clipBy(clipper : Padi, holder : inout [Padi], climber: AdaptiveSkeletonClimber, farm : Farm?, block : Block?) {
                    
        var dikeset = [Int](repeating: 0, count: AdaptiveSkeletonClimber.N)
        var dikecnt = 0
                
        let ligngiven = lignavail && farm != nil
        let clipxstart = Dike.start(clipper.dike[3])
        let clipxend   = Dike.end(clipper.dike[3])
        let clipystart = Dike.start(clipper.dike[2])
        let clipyend   = Dike.end(clipper.dike[2])
        let thisxstart = Dike.start(dike[3])
        let thisxend   = Dike.end(dike[3])
        let thisystart = Dike.start(dike[2])
        let thisyend   = Dike.end(dike[2])

        if (thisxstart < clipxstart || thisxend > clipxend) {
            // divide along x axis
            if (thisxstart < clipxstart) {
                dikecnt = 0
                Dike.MinDikeSet(minidx: thisxstart, maxidx: clipxstart - 1, dike: &dikeset)
                for i in 0 ..< dikecnt {
                    // append into the holder array
                    if (!ligngiven) {
                        holder.append(Padi(climber: climber, xdike: dikeset[i], ydike: dike[PadiSide.left.rawValue], farm: farm, block: block))
                    } else {
                        holder.append(Padi(climber: climber, xdike: dikeset[i], ydike: dike[PadiSide.left.rawValue], farm: farm, block: block))
                    }
                }
            }
            if (thisxend > clipxend) {
                dikecnt = 0
                Dike.MinDikeSet(minidx: clipxend, maxidx: thisxend - 1, dike: &dikeset)
                for i in 0 ..< dikecnt {
                    // append into the holder array
                    if (!ligngiven) {
                        holder.append(Padi(climber: climber, xdike: dikeset[i], ydike: dike[PadiSide.left.rawValue], farm: farm, block: block))
                    } else {
                        holder.append(Padi(climber: climber, xdike: dikeset[i], ydike: dike[PadiSide.left.rawValue], farm: farm, block: block))
                    }
                }
            }
        }
        if (thisystart < clipystart || thisyend > clipyend) {
            // divide along y
            if (thisystart < clipystart) {
                dikecnt = 0
                Dike.MinDikeSet(minidx: thisystart, maxidx: clipystart-1, dike: &dikeset)
                for i in 0 ..< dikecnt {
                    // append into the holder array
                    if (!ligngiven) {
                        holder.append(Padi(climber: climber, xdike: dike[PadiSide.bottom.rawValue], ydike: dikeset[i], farm: farm, block: block))
                    } else {
                        holder.append(Padi(climber: climber, xdike: dike[PadiSide.bottom.rawValue], ydike: dikeset[i], farm: farm, block: block))
                    }
                }
            }
            if (thisyend > clipyend) {
                dikecnt = 0
                Dike.MinDikeSet(minidx: clipyend, maxidx: thisyend - 1, dike: &dikeset)
                for i in 0 ..< dikecnt {
                    // append into the holder array
                    if (!ligngiven) {
                        holder.append(Padi(climber: climber, xdike: dike[PadiSide.bottom.rawValue], ydike: dikeset[i], farm: farm, block: block))
                    } else {
                        holder.append(Padi(climber: climber, xdike: dike[PadiSide.bottom.rawValue], ydike: dikeset[i], farm: farm, block: block))
                    }
                }
            }
        }     
    }



    /// output the 2D slice and padi as a postscript image  *
    static func out2DPadiPS(climber: AdaptiveSkeletonClimber, farm : Farm, offx : Int, offy : Int, offz : Int) {
            
        let radius = 1 * 5.0
        let spacing = 10 * 5.0
        let offset = 2 * 5.0

        print("%%!\n100 100 translate\ngsave\n");
        // Draw the data point
        let xis = farm.XisV()
        let yis = farm.YisV()
        
        var dim = [Int](repeating: -1, count: 3)
        dim[farm.fixDimV().rawValue] = farm.fixDimValV()
        dim[xis.rawValue] = -1
        dim[yis.rawValue] = 0        
        for j in 0 ..< AdaptiveSkeletonClimber.N + 1 {
            dim[yis.rawValue] = j
            let data = VoxelData(climber: climber, x: dim[0], y: dim[1], z: dim[2], offx: offx, offy: offy, offz: offz)
            for i in 0 ..< AdaptiveSkeletonClimber.N + 1 {
                if (data[i] > 0) {
                    // above threshold, represented by cross
                    print("newpath %f %f moveto %f %f lineto stroke closepath\n",
                           Double(i) * spacing - radius, Double(j) * spacing - radius, Double(i) * spacing + radius,
                           Double(j) * spacing + radius)
                    print("newpath %f %f moveto %f %f lineto stroke closepath\n",
                           Double(i) * spacing - radius, Double(j) * spacing + radius, Double(i) * spacing + radius,
                           Double(j) * spacing - radius)
                } else {
                    // below threshold, represented by hollow circle
                    print("newpath %f %f %f 0 360 arc stroke closepath\n", Double(i) * spacing, Double(j) * spacing, radius);
                }
            }
        }

        // Draw the padi
        for currpadi in farm.padilist {
            currpadi.draw2D(spacing: spacing, offset: offset)
        }
        print("grestore\nshowpage\n");
    }
}
