//
//  HighRice.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 16/07/2020.
//

import Foundation

enum HighRiceSide : Int {
    case bottom = 0
    case top = 1
    case nearXZ = 2
    case farXZ = 3
    case nearYZ = 4
    case farYZ = 5
    case invalid
}

// Notice the notation change, from left to right, we call +ve X,
// From near to far, we call +ve Y. From bottom to top, we call +ve Z.
// although HighRice inherent from Padi, it only used the array dike[]
// EnclosedByQ(), OverlapQ() and ClipBy() functions.

class HighRice : Padi {
    private var edgeno : Int    // no of unit edges on the surface of the highrice
                                // edgeno = 4 *(pq + qr + rp)   is no of edges of p x q x r highrice
    private var offset = [Int](repeating: 0, count: 6)   // offset pointer to the 1st entry of each face of highrice
    private var width : Int {
        get {
            return Dike.length(dike[PadiSide.top.rawValue])
        }
    }
    private var height : Int {
        get {
            return top - bottom + 1
        }
    }
    private var depth : Int {
        get {
            return Dike.length(dike[PadiSide.left.rawValue])
        }
    }
    
    private var isEmpty : Bool

    // identify the highrice with width dike (dike[1])
    // and depth dike (dike[0]) and [bottom,top]
    // bottom < top
    public var bottom : Int
    public var top : Int
                        
    internal init(x : Int, y : Int, b : Int, t : Int) {
        assert(!(x < 1 || x >= AdaptiveSkeletonClimber.SIZE || y < 1 || y >= AdaptiveSkeletonClimber.SIZE || b < 0 || b >= AdaptiveSkeletonClimber.N || t < 0 || t >= AdaptiveSkeletonClimber.N), "[HighRice::Init]: invalid input value\n")
        
        dike = [
            y, //right
            x, //top
            y, //left
            x  //bottom
        ]
              
        bottom = min(b, t)
        top = max(b, t)
        isEmpty = false
    }


    // Check whether this highrice is enclosed by encloser.
    // We consider a enclose b even if a==b.
    override func enclosedByQ(_ encloser : Padi) -> Bool {
        guard let encloserHighRice = encloser as? HighRice else { return false }
        if (encloserHighRice.bottom > bottom || encloserHighRice.top < top) {
            // check along Z direction
            return false
        }
        return super.enclosedByQ(encloser)
    }


    // Check whether this highrice overlaps with input highrice
    override func overlapQ(padi : Padi) -> Bool {
        guard let highRice = padi as? HighRice else { return false }
        
        if (highRice.top < bottom || highRice.bottom > top) {
            // check along Z direction
            return false
        }
        return super.overlapQ(padi: padi)
    }


    func clipBy(clipper : HighRice, holder : inout [HighRice], climber: AdaptiveSkeletonClimber) {
        var padiholder : [Padi] = []
        padiholder.reserveCapacity(AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N)
        
        // Cut along Z direction
        var upperbnd = top
        var lowerbnd = bottom
        if (top > clipper.top) {
            holder.append(HighRice(x: dike[PadiSide.top.rawValue], y: dike[PadiSide.right.rawValue], b: clipper.top + 1, t: top))
            upperbnd = clipper.top
        }
        if (bottom < clipper.bottom) {
            holder.append(HighRice(x: dike[PadiSide.top.rawValue], y: dike[PadiSide.right.rawValue], b: bottom, t: clipper.bottom - 1))
            lowerbnd = clipper.bottom;
        }

        // Now only the same interval along z need to be clipped
        super.clipBy(clipper: clipper, holder: &padiholder, climber: climber, farm: nil, block: nil)
        
        // for each 2D clipped padi, generate a highrice
        for padi in padiholder {
            holder.append(HighRice(x: padi.dike[PadiSide.top.rawValue], y: padi.dike[PadiSide.left.rawValue],
                                   b: lowerbnd, t: upperbnd))
        }
    }



    // setup the edgetable and
    func setupEdgeTable(xyfarm : [Farm], xzfarm : [Farm], yzfarm : [Farm], edge : inout [Int]) {
        
        var ytop = 0
        var ybottom = 0
        var xdike = 0
        
        var edgearr : [PadiSide] = []
        edgearr.reserveCapacity(4)
        
        var face : String = ""
        var occupiant : [Padi] = []
        occupiant.reserveCapacity(AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N)
        
        var currfarm : Farm? = nil
      
        // total no of unit edges
        let edgeno = 4 * (width * depth + height * width + height * depth)
        offset[HighRiceSide.bottom.rawValue] = 0
        offset[HighRiceSide.top.rawValue] = width * depth * 2
        offset[HighRiceSide.nearXZ.rawValue] = offset[HighRiceSide.top.rawValue] + width * depth * 2
        offset[HighRiceSide.farXZ.rawValue] = offset[HighRiceSide.nearXZ.rawValue] + width * height * 2
        offset[HighRiceSide.nearYZ.rawValue] = offset[HighRiceSide.farXZ.rawValue] + width * height * 2
        offset[HighRiceSide.farYZ.rawValue] = offset[HighRiceSide.nearYZ.rawValue] + depth * height * 2

        // init the input global edge table array
        for k in 0 ..< 2 * edgeno {
            edge[k] = -1
        }

        #if DEBUG
        print("\n\nhighrice %d x %d x [%d %d]\n", dike[PadiSide.top.rawValue], dike[PadiSide.left.rawValue], bottom, top);
        #endif
        // get the padis of each face of the highrice
        for i in 0 ..< 6 {
            guard let side = HighRiceSide(rawValue: i) else { continue }
            
            switch (side) {
            case .bottom:
                currfarm = xyfarm[bottom]
                face = "bottom: "
                ybottom = Dike.start(dike[PadiSide.left.rawValue])
                ytop = Dike.end(dike[PadiSide.left.rawValue]) - 1
                xdike = dike[PadiSide.top.rawValue]
            case .top:
                currfarm = xyfarm[top + 1]
                face = "top: "
                ybottom = Dike.start(dike[PadiSide.left.rawValue])
                ytop = Dike.end(dike[PadiSide.left.rawValue]) - 1
                xdike = dike[PadiSide.top.rawValue]
            case .nearXZ:
                currfarm = xzfarm[Dike.start(dike[PadiSide.left.rawValue])]
                face = "near xz: "
                ybottom = bottom
                ytop = top
                xdike = dike[PadiSide.top.rawValue]
            case .farXZ:
                currfarm = xzfarm[Dike.end(dike[PadiSide.left.rawValue])]
                face = "far xz: "
                ybottom = bottom
                ytop = top
                xdike = dike[PadiSide.top.rawValue]
            case .nearYZ:
                currfarm = yzfarm[Dike.start(dike[PadiSide.top.rawValue])]
                face = "near yz: "
                ybottom = bottom
                ytop = top
                xdike = dike[PadiSide.left.rawValue]
            case .farYZ:
                currfarm = yzfarm[Dike.end(dike[PadiSide.top.rawValue])]
                face = "far yz: "
                ybottom = bottom
                ytop = top
                xdike = dike[PadiSide.left.rawValue]
            default:
                break
            }

            // find occupiant of current face
            occupiant.removeAll(keepingCapacity: true)
            for j in ybottom ... ytop {
                currfarm!.xstrip[j].usedBy(dike: xdike, occup: &occupiant)
            }

            // for each occupy padi
            for occupant in occupiant {
                if (Dike.start(occupant.dike[PadiSide.top.rawValue]) < Dike.start(xdike)
                    ||  Dike.end(occupant.dike[PadiSide.top.rawValue]) > Dike.end(xdike)
                    ||  Dike.start(occupant.dike[PadiSide.left.rawValue]) < ybottom
                    ||  Dike.end(occupant.dike[PadiSide.left.rawValue]) - 1 > ytop) {
                    print("vvvvvvvvvvvvvvv padi out of highrice face bound\n");
                }
            #if DEBUG
                print("%s %d x %d\n", face, occupant.dike[PadiSide.top.rawValue], occupant.dike[PadiSide.left.rawValue]);
            #endif

                // find the edges on each padi
                edgearr.removeAll(keepingCapacity: true)
                occupant.genEdge(edgearr: &edgearr)
                for k in stride(from: 0, to: edgearr.count, by: 2) {
                    let from = mapToEdgeTable(face: side, farm: currfarm!, padi: occupant, side: edgearr[k])
                    let to = mapToEdgeTable(face: side, farm: currfarm!, padi: occupant, side: edgearr[k + 1])
                    if (from < 0 || to < 0 || from >= edgeno || to >= edgeno) {
                        print("[HighRice::SetupEdgeTable]: map to wrong index %d to %d (edgeno=%d)\n", from, to, edgeno)
                    }
                    // duplicate 2 edge in opposite direction and fill up the double
                    // sized array
                    // Since I find that the edge generated may not be consistent
                    // chained together, I use an algorithm tosolve this problem.
                    // All edges are duplicated in reversed direction
                    // i.e. if there is edge k->l then duplicated an edge from
                    // l->k. Fill the edge table kth entry by l and (l+edgeno)th
                    // entry by k. Hence we need an array of size 2*edgeno.
                    // When finish filling, search the first nonnegative element
                    // and mark it as the first node in the loop and start looping
                    // if edge[curr] != prev
                    //   curr = edge[curr]
                    // else
                    //   curr = edge[curr+edgeno]
                    if (edge[from] == -1) {
                        edge[from] = to
                    } else if (edge[edgeno + from] == -1) {
                        edge[edgeno + from] = to
                    } else {
                        // unexpected array full
                        print("[HighRice::SetupEdgeTable]: edge collide %d -> %d\n", from, to)
                    }
                    if (edge[to] == -1) {
                        edge[to] = from
                    } else if (edge[edgeno + to] == -1) {
                        edge[edgeno + to] = from
                    } else {
                        // unexpected array full
                        print("[HighRice::SetupEdgeTable]: doubled edge collide %d -> %d\n", to, from)
                    }

                    #if DEBUG
                    let fromstr = String(describing: edgearr[k])
                    let tostr = String(describing: edgearr[k + 1])
                    print("edge: from %@ to %@\n", fromstr, tostr)
                    #endif
                }
                #if DEBUG
                print("\nedge table arr:\n")
                for k in 0 ..< 2 * edgeno {
                    print("%d ", edge[k])
                }
                print("\n\n");
                #endif
            }
        }
    }



    func mapToEdgeTable(face : HighRiceSide, farm : Farm, padi : Padi, side : PadiSide) -> Int {

        var fx : Int
        var fy : Int
        
        // take appropiate coordinate relative to the farm's origin
        switch (side) {
        case .bottom:
            fx = Dike.start(padi.dike[PadiSide.top.rawValue])
            fy = Dike.start(padi.dike[PadiSide.left.rawValue])
        case .top:
            fx = Dike.start(padi.dike[PadiSide.top.rawValue])
            fy = Dike.end(padi.dike[PadiSide.left.rawValue])
        case .left:
            fx = Dike.start(padi.dike[PadiSide.top.rawValue])
            fy = Dike.start(padi.dike[PadiSide.left.rawValue])
        case .right:
            fx = Dike.end(padi.dike[PadiSide.top.rawValue])
            fy = Dike.start(padi.dike[PadiSide.left.rawValue])
        default:
            return -1
        }
        
        let horiz = side == .top || side == .bottom
        let intersect : Int
        if (horiz) {
            // horizontal relative to the farm
            intersect = farm.xlign[fy].ver(padi.dike[side.rawValue])
        } else {
            intersect = farm.ylign[fx].ver(padi.dike[side.rawValue])
        }
        if (intersect == 0) {
            // no intersection
            print("[HighRice::MaptoEdgeTable]: input padi side has no intersection\n")
            return -1
        }
        if (horiz) {
            fx = intersect - AdaptiveSkeletonClimber.N
        } else {
            fy = intersect - AdaptiveSkeletonClimber.N
        }
        
        let index : Int

        switch(face) {
        case .bottom:
            fx -= Dike.start(dike[PadiSide.top.rawValue])
            fy -= Dike.start(dike[PadiSide.left.rawValue])
            // transform to highrice face's coordinate
            if (horiz) {
                // horizontal edge fill the even entries
                if (fy == 0) {
                    // pass to HR_NEARXZ
                    index = offset[HighRiceSide.nearXZ.rawValue] + 2 * (fx)
                } else {
                    index = offset[HighRiceSide.bottom.rawValue] + 2 * ((fy - 1) * width + fx)
                }
            } else {
                // vertical edges fill the odd entries
                if (fx == 0) {
                    // pass to HR_NEARYZ and side become horizontal
                    index = offset[HighRiceSide.nearYZ.rawValue] + 2 * (fy)
                } else {
                    index = offset[HighRiceSide.bottom.rawValue] + 2 * (fy * width + (fx - 1)) + 1
                }
            }

        case .top:
            fx -= Dike.start(dike[PadiSide.top.rawValue])
            fy -= Dike.start(dike[PadiSide.left.rawValue])
            if (horiz) {
                if (fy == depth) {
                    // pass to HR_FARXZ
                    index = offset[HighRiceSide.farXZ.rawValue] + 2 * ((height - 1) * width + fx)
                } else {
                    index = offset[HighRiceSide.top.rawValue]   + 2 * (fy * width + fx)
                }
            } else {
                if (fx == width) {
                    // pass to HR_FARYZ and side become horizontal
                    index = offset[HighRiceSide.farYZ.rawValue] + 2 * ((height - 1) * depth + fy)
                } else {
                    index = offset[HighRiceSide.top.rawValue]   + 2 * (fy * width + fx) + 1
                }
            }

        case .nearXZ:
            fx -= Dike.start(dike[PadiSide.top.rawValue])
            fy -= bottom
            if (horiz) {
                if (fy == height) {
                    // pass to HR_TOP
                    index = offset[HighRiceSide.top.rawValue]    + 2 * (fx)
                } else {
                    index = offset[HighRiceSide.nearXZ.rawValue] + 2 * (fy * width + fx)
                }
            } else {
                if (fx == width) {
                    //pass to HR_FARYZ
                    index = offset[HighRiceSide.farYZ.rawValue]  + 2 * (fy * depth) + 1
                } else {
                    index = offset[HighRiceSide.nearXZ.rawValue] + 2 * (fy * width + fx) + 1
                }
            }

        case .farXZ:
            fx -= Dike.start(dike[PadiSide.top.rawValue])
            fy -= bottom
            if (horiz) {
                if (fy==0) {
                    // pass to HR_BOTTOM
                    index = offset[HighRiceSide.bottom.rawValue] + 2 * ((depth - 1) * width + fx)
                } else {
                  index = offset[HighRiceSide.farXZ.rawValue]  + 2 * ((fy - 1) * width + fx)
                }
            } else {
                if (fx == 0) {
                    // pass to HR_NEARYZ
                    index = offset[HighRiceSide.nearYZ.rawValue] + 2 * (fy * depth + depth - 1) + 1
                } else {
                    index = offset[HighRiceSide.farXZ.rawValue]  + 2 * (fy * width + fx - 1) + 1
                }
            }

        case .nearYZ:
            fx -= Dike.start(dike[PadiSide.left.rawValue])
            fy -= bottom
            if (horiz) {
                if (fy == height) {
                    // pass to HR_TOP  and side become vertical
                    index = offset[HighRiceSide.top.rawValue]    + 2*(fx * width) + 1;
                } else {
                    index = offset[HighRiceSide.nearYZ.rawValue] + 2*(fy * depth + fx);
                }
            } else {
                if (fx==0) {
                    // pass to HR_NEARXZ
                    index = offset[HighRiceSide.nearXZ.rawValue] + 2*(fy * width) + 1;
                } else {
                    index = offset[HighRiceSide.nearYZ.rawValue] + 2*(fy*depth + fx - 1) + 1
                }
            }

        case .farYZ:
            fx -= Dike.start(dike[PadiSide.left.rawValue])
            fy -= bottom
            if (horiz) {
                if (fy == 0) {
                    // pass to HR_BOTTOM and side become vertical
                    index = offset[HighRiceSide.bottom.rawValue] + 2 * (fx * width + width - 1) + 1
                } else {
                    index = offset[HighRiceSide.farYZ.rawValue]  + 2 * ((fy - 1) * depth + fx)
                }
            } else {
                if (fx == depth) {
                    // pass to HR_FARXZ
                    index = offset[HighRiceSide.farXZ.rawValue]  + 2 * (fy * width + width - 1) + 1
                } else {
                    index = offset[HighRiceSide.farYZ.rawValue]  + 2 * (fy * depth + fx) + 1
                }
            }
            
        default:
            return -1
        }
        return index
    }



    func generatePath(path : inout [Int], pathcnt : inout [Int], edge : inout [Int]) {
        //int , start, nextidx,
        var start = 0

        path.removeAll(keepingCapacity: true)
        
        // find all the loop
        while (start < edgeno) {
            while (start < edgeno) {
                if (edge[start] >= 0) {
                    break;
                }
                start += 1
            }
            if (start >= edgeno) {
                break
            }
            var i = start // ?? var ??
            var previdx = -1
            #if DEBUG
            print("\n%d ", i)
            #endif
            var pathLength = 0
            path.append(start)
            pathLength += 1
            while true {
                let nextidx : Int
                if (edge[i] != previdx) {
                    // go on to next node and mark it as read i.e. -ve
                    nextidx = edge[i]
                    edge[i] -= edgeno + 1
                    edge[i + edgeno] -= edgeno + 1
                } else {
                    nextidx = edge[i + edgeno]
                    edge[i] -= edgeno + 1
                    edge[i + edgeno] -= edgeno + 1
                }
                if (nextidx == start) {
                    // the loop is completed
                    break
                }
                if (nextidx >= 0) {
                    #if DEBUG
                    print("-> %d ", nextidx)
                    #endif
                    // record it in an array
                    path.append(nextidx)
                    pathLength += 1
                
                    assert(!(path.count > edgeno || pathcnt.count > 8 ), "[HighRice::GeneratePath]: not enough memory allocated\n")
                } else {
                    print(false, "[HighRice::GeneratePath]: edge loop not complete!!\n")
                    return
                }
                previdx = i
                i = nextidx
            }
            pathcnt.append(pathLength)
        }
    }



    // map the edge table index to the coordinate relative to the block
    // the coordinate is described by the
    // xyz       Indicates the edge is along x, y or z direction
    // coord[0]  The x y and z coordinates of the bottom left near xz
    // coord[1]  corner of the unit cube which the edge belong to.
    // coord[2]  Note that each cube hold 3 edges
    //     z     which are
    //      |  / y
    //      |/___ x
    func indexToCoord(idx : inout Int, coord : inout [Int], xyz : inout Dimension) {
        assert(!(idx < 0 || idx >= edgeno), "[HighRice::IndexToCoord]: invalid input value\n")
        
        var face = 0
        while (face < 5) {
            if (idx >= offset[face] && idx < offset[face + 1]) {
                break
            }
            face += 1
        }
        
        idx -= offset[face]
        let vertical = (idx & 0x01) > 0
        idx >>= 1
        switch (face)
        {
        case HighRiceSide.bottom.rawValue:
            xyz = vertical ? .y : .x
            coord[0] = vertical ? modulo(idx, width) + 1 + Dike.start(dike[PadiSide.top.rawValue]) : modulo(idx, width) + Dike.start(dike[PadiSide.top.rawValue])
            coord[1] = vertical ? idx / width + Dike.start(dike[PadiSide.left.rawValue])  : idx / width + 1 + Dike.start(dike[PadiSide.left.rawValue])
            coord[2] = bottom

        case HighRiceSide.top.rawValue:
            xyz = vertical ? .y : .x
            coord[0] = modulo(idx, width) + Dike.start(dike[PadiSide.top.rawValue])
            coord[1] = idx / width + Dike.start(dike[PadiSide.left.rawValue])
            coord[2] = top + 1

        case HighRiceSide.nearXZ.rawValue:
            xyz = vertical ? .z : .x
            coord[0] = modulo(idx, width) + Dike.start(dike[PadiSide.top.rawValue])
            coord[1] = Dike.start(dike[PadiSide.left.rawValue])
            coord[2] = idx / width + bottom

        case HighRiceSide.farXZ.rawValue:
            xyz = vertical ? .z : .x
            coord[0] = vertical ? modulo(idx, width) + 1 + Dike.start(dike[PadiSide.top.rawValue]) : modulo(idx, width) + Dike.start(dike[PadiSide.top.rawValue])
            coord[1] = Dike.end(dike[PadiSide.left.rawValue])
            coord[2] = vertical ? idx / width + bottom : idx / width + 1 + bottom

        case HighRiceSide.nearYZ.rawValue:
            xyz = vertical ? .z : .y
            coord[0] = Dike.start(dike[PadiSide.top.rawValue]);
            coord[1] = vertical ? modulo(idx, depth) + 1 + Dike.start(dike[PadiSide.left.rawValue]) : modulo(idx, depth) + Dike.start(dike[PadiSide.left.rawValue])
            coord[2] = idx / depth + bottom

        case HighRiceSide.farYZ.rawValue:
            xyz = vertical ? .z : .y
            coord[0] = Dike.end(dike[PadiSide.top.rawValue]);
            coord[1] = modulo(idx, depth) + Dike.start(dike[PadiSide.left.rawValue]);
            coord[2] = vertical ? idx / depth + bottom : idx/depth+1 + bottom;
            
        default:
            break
        }
    }


    func checkEmpty(xyfarm : [Farm]) -> Bool {
        var occupied = false
        let sx = Dike.start(dike[PadiSide.top.rawValue])
        let ex = Dike.end(dike[PadiSide.top.rawValue])
        let sy = dike[PadiSide.left.rawValue]
        let ey = Dike.end(dike[PadiSide.left.rawValue])
        for i in bottom ... top+1 {
            let farm = xyfarm[i]
            occupied = occupied
                      || farm.xlign[sy].occ(1) > 0
                      || farm.xlign[ey].occ(1) > 0
                      || farm.ylign[sx].occ(1) > 0
                      || farm.ylign[ex].occ(1) > 0
        }
        if (occupied) {
            self.isEmpty = false
        } else {
            self.isEmpty = true
        }
        return self.isEmpty
    }


    /********************************************************
     * output the 3D highrices as a intermediate format for
     * external program to process and display the highrices
     * interactively.
     ********************************************************/
    static func out3DHighRice(climber : AdaptiveSkeletonClimber, farms : [Farm], highricelist : DoublyLinkedList<HighRice>, offx : Int, offy : Int, offz : Int) {
//      int i, j, k, dim[3];
//      HighRice *currhrice;
//      CHAR xis, yis, zis;
//
//      // Output the HighRice dimension
//      printf ("Highrice start\n");
//      for (currhrice=(HighRice*)highricelist->First() ; currhrice!=NULL ; currhrice=(HighRice*)highricelist->Next())
//        printf ("%d %d %d %d\n", currhrice.dike[PadiSide.top.rawValue], currhrice.dike[PadiSide.bottom.rawValue],
//                currhrice->bottom, currhrice->top);
//
//      // Draw the data point
//      printf ("Data start\n");
//      xis = farm[0].XisV();
//      yis = farm[0].YisV();
//      zis = 3 & (~(xis|yis));
//      dim[zis] = 0;
//      dim[xis] = -1;
//      dim[yis] = 0;
//      VoxelData data(data1, dim[0], dim[1], dim[2], offx, offy, offz, datadimx, datadimy, datadimz);
//      // Use the correct orientation to output the data point
//      for (k=0 ; k<N+1 ; k++)
//      {
//        dim[zis]=k; // advance z
//        for (j=0 ; j<N+1 ; j++)
//        {
//          dim[yis]=j; // advance y
//          data.ReInit(data1, dim[0], dim[1], dim[2], offx, offy, offz, datadimx, datadimy, datadimz);
//          for (i=0 ; i<N+1 ; i++)
//            printf ("%d ", data[i]);
//          printf("\n");
//        }
//        printf("\n");
//      }
    }


    static func highRiceStatistic(_ highricelist : DoublyLinkedList<HighRice>) {
    
        var count = [Int](repeating: 0, count: AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N)

        for highrice in highricelist {
            let height = highrice.top - highrice.bottom + 1
            let b1 = Dike.start(highrice.dike[PadiSide.left.rawValue])
            let e1 = Dike.end(highrice.dike[PadiSide.left.rawValue])
            let b2 = Dike.start(highrice.dike[PadiSide.top.rawValue])
            let e2 = Dike.end(highrice.dike[PadiSide.top.rawValue])
            for j in b1 ..< e1 {
                for i in b2 ..< e2 {
                    count[j * AdaptiveSkeletonClimber.N + i] += height
                }
            }
        }
        print("No of voxel occupied in each vertical highrice:\n");
        for j in (0 ..< AdaptiveSkeletonClimber.N).reversed() {
            for i in 0 ..< AdaptiveSkeletonClimber.N {
                print("%d ", count[j * AdaptiveSkeletonClimber.N + i])
            }
        
            print("\n")
        }
        print("\n")

        // Check whether there is overlapped voxel
        print("Checking whether highrices overlapped\n");
        for i in 0 ..< AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N {
            count[i] = 0
        }
        for highrice in highricelist {
            //let height = highrice.top - highrice.bottom + 1;
            let b1 = Dike.start(highrice.dike[PadiSide.left.rawValue])
            let e1 = Dike.end(highrice.dike[PadiSide.left.rawValue])
            let b2 = Dike.start(highrice.dike[PadiSide.top.rawValue])
            let e2 = Dike.end(highrice.dike[PadiSide.top.rawValue])
            for k in highrice.bottom ... highrice.top {
                for j in b1 ..< e1 {
                    for i in b2 ..< e2 {
                        if (count[k * AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N + j * AdaptiveSkeletonClimber.N + i] != 0) {
                            print("Overlap at (%d %d %d)\n", i, k, j);
                        }
                        count[k * AdaptiveSkeletonClimber.N * AdaptiveSkeletonClimber.N + j * AdaptiveSkeletonClimber.N + i] += 1
                    }
                }
            }
        }
        print("\n\n");
    }
}
