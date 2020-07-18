//
//  AdaptiveSkeletonClimber.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 08/07/2020.
//

struct DataBlock {
    
}

internal func modulo<T: BinaryInteger>(_ lhs: T, _ rhs: T) -> T {
    let rem = lhs % rhs // -rhs <= rem <= rhs
    return rem >= 0 ? rem : rem + rhs
}

class AdaptiveSkeletonClimber {
    private let bkwidth : Int
    private let bkdepth : Int
    private let bkheight : Int
    
    internal static let NLEVEL = 4  /*  number of level of the binary structure */
    internal static let N = 16  /* (1<<NLEVEL),number of intervals along 1 lign         */
    internal static let SIZE = 32  /* (1<<(NLEVEL+1)), number of dikes in binary tree stucture  */
    internal static let DSIZE = 64 /* (1<<(NLEVEL+2)), double of SIZE */

    static let G_Threshold = 50.0
    static let G_WidthScale = 1.0
    static let G_HeightScale = 1.0
    static let G_DepthScale = 1.0
    static let G_WidthScale_2 = G_WidthScale / 2
    static let G_HeightScale_2 = G_HeightScale / 2
    static let G_DepthScale_2 = G_DepthScale / 2
    static let G_AngleThresh = 15.0 * Double.pi / 180.0
    static let G_CosAngleThresh = cos(G_AngleThresh);
    static let G_HandleAmbiguity = true
    
    private let indexData : [DataBlock]
    
    init(indexData : [DataBlock]) {
        bkwidth = 16
        bkdepth = 16
        bkheight = 16
        self.indexData = indexData
        
        Dike.DikeTableInit()
        Padi.PadiInitEdgeTable()
    }
    
    func climb() {
        var idxcnt = [0, 0, 0]
        let layersize = bkwidth * bkdepth
        
        let blockData = [CUnsignedChar](repeating: 0, count: 10 * 10 * 10)

        // 3 layers of blocks should be hold in memory
        var layer = [[Block]](repeating: [Block](repeating: Block(blockData: blockData, dataDimX: 10, dataDimY: 10, dataDimZ: 10), count: layersize), count: 3)
        
        #if KDTREE
        
        var idxlayer = [[Int]](repeating: [Int](repeating: 0, count: layersize), count: 3)
        
        for k in 0 ..< bkheight + 2 { // process in a layer-by-layer fashion
            let k_0 = modulo(k, 3)
            let k_1 = modulo(k - 1, 3)
            let k_2 = modulo(k - 2, 3)
            
            let kminus0 = layer[k_0] // layer k
            let kminus1 = layer[k_1] // layer k-1
            let kminus2 = layer[k_2] // layer k-2

            if (k < bkheight) {
                print("Processing layer %d ...\n", k * AdaptiveSkeletonClimber.N)
                for i in 0 ..< layersize {
                    kminus0[i].setEmpty()  // Set all block in current layer to empty
                }
                
                idxcnt[k_0] = 0
                QueryKdTree(kdtree, k, AdaptiveSkeletonClimber.NLEVEL, AdaptiveSkeletonClimber.G_Threshold, idxlayer[k_0], layersize, idxcnt[k_0])
                
                // process each non empty block
                for i in 0 ..< idxcnt[k_0] {
                    let db = indexData[idxlayer[k_0][i]]
                    let cx = db.XisQ()
                    let cy = db.YisQ()
                    let cz = db.ZisQ()
                    let currxy = cy * bkwidth + cx
                    kminus0[currxy].unsetEmpty() // set it to non empty block
                    kminus0[currxy].Init(G_data1, XDIM, YDIM, ZDIM, AdaptiveSkeletonClimber.N * cx, AdaptiveSkeletonClimber.N * cy, AdaptiveSkeletonClimber.N * cz, G_DataWidth, G_DataDepth, G_DataHeight)
                    kminus0[currxy].buildHighRice()  // skip when empty
                }
            }
            if (k >= 1 && k - 1 < bkheight) { // process previous layer again
                for i in 0 ..< idxcnt[k_1] {  // communcate block in previous layers
                    let db = indexData[idxlayer[k_1][i]]
                    let cx = db.XisQ()
                    let cy = db.YisQ()
                    let cz = db.ZisQ()
                    let currxy = cy * bkwidth + cx
                    let bottom = (k == 1) ?             nil : kminus2[currxy]
                    let top    = (k == bkheight) ?      nil : kminus0[currxy]
                    let nearxz = (cy == 0) ?            nil : kminus1[(cy-1) * bkwidth + cx]
                    let farxz  = (cy == bkdepth - 1) ?  nil : kminus1[(cy+1) * bkwidth + cx]
                    let nearyz = (cx == 0) ?            nil : kminus1[cy * bkwidth + (cx - 1)]
                    let faryz  = (cx == bkwidth - 1) ?  nil : kminus1[cy * bkwidth + (cx + 1)]
                    kminus1[currxy].communicateSimple(bottom, top, nearxz, farxz, nearyz, faryz)
                    kminus1[currxy].generateTriangle(format, withnormal, fptr)
                }
            }
            if (k >= 2) { // process layer k-2
                for i in 0 ..< idxcnt[k_2] {  // communcate block in previous layers
                    let db = indexData[idxlayer[k_2][i]]
                    let cx = db.XisQ()
                    let cy = db.YisQ()
                    let currxy = cy * bkwidth + cx
                    kminus2[currxy].cleanup()
                }
            }
        }
#else
        for k in 0 ..< bkheight + 2 {
            let kminus0 = layer[modulo(k, 3)]       // layer k
            let kminus1 = layer[modulo(k - 1, 3)]   // layer k-1
            let kminus2 = layer[modulo(k - 2, 3)]   // layer k-2
            if (k < bkheight) {
                print("Processing layer %d ...\n", k * AdaptiveSkeletonClimber.N)
            }
            for j in 0 ..< bkdepth {
                for i in 0 ..< bkwidth {
                    let currij = j * bkwidth + i
                    if (k < bkheight) {
                        kminus0[currij].Init(G_data1, XDIM, YDIM, ZDIM, AdaptiveSkeletonClimber.N * i, AdaptiveSkeletonClimber.N * j, AdaptiveSkeletonClimber.N * k, G_DataWidth, G_DataDepth, G_DataHeight)
                        if (!kminus0[currij].emptyQ()) {
                            // skip when empty
                            kminus0[currij].buildHighRice()
                        }
                    }
                    if (k >= 1 && k - 1 < bkheight && !kminus1[currij].emptyQ()) {
                        let bottom = (k == 1) ?         nil : &(kminus2[currij])
                        let top    = (k == bkheight) ?  nil : &(kminus0[currij])
                        let nearxz = (j == 0) ?         nil : &(kminus1[(j - 1) * bkwidth + i])
                        let farxz  = (j == bkdepth - 1) ? nil : &(kminus1[(j + 1) * bkwidth + i])
                        let nearyz = (i == 0) ?         nil : &(kminus1[j * bkwidth + i - 1])
                        let faryz  = (i == bkwidth - 1) ? nil : &(kminus1[j * bkwidth + i + 1])
                        kminus1[currij].communicateSimple(bottom, top, nearxz, farxz, nearyz, faryz)
                        kminus1[currij].generateTriangle(format, withnormal, fptr)
                    }

                    if (k >= 2 && !kminus2[currij].emptyQ()) {
                        // skip when empty, assume Init() do not allocate memory
                        kminus2[currij].cleanup()
                    }
                }
            }
        }
#endif
    }
}
