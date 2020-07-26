//
//  Slice.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 24/07/2020.
//

import Foundation
import Euclid

public class SurfaceNet {
    private let contourTracer : ContourTracer
    private let dimensions : [Int]
    
    static let cubeEdges = configureCubeEdges()
    static let edgeTable = configureEdgeTable()
    
    static func configureCubeEdges() -> [Int] {
        //Initialize the cube_edges table
        // This is just the vertex number of each cube
        var k = 0;
        var cubeEdges = [Int](repeating: 0, count: 24)
        for i in 0 ..< 8 {
            var j = 1
            while (j <= 4) {
                let p = i ^ j
                if (i <= p) {
                    cubeEdges[k] = i
                    cubeEdges[k + 1] = p
                    k += 2
                }
                j <<= 1
            }
        }
        return cubeEdges
    }
    
    static func configureEdgeTable() -> [Int] {
        //Initialize the intersection table.
        //  This is a 2^(cube configuration) ->  2^(edge configuration) map
        //  There is one entry for each possible cube configuration, and the output is a 12-bit vector enumerating all edges crossing the 0-level.
        var edgeTable = [Int](repeating: 0, count: 256)
        for i in 0 ..< 256 {
            var em = 0
            for j in stride(from: 0, to: 24, by: 2) {
                let a = (i & (1 << cubeEdges[j])) > 0
                let b = (i & (1 << cubeEdges[j + 1])) > 0
                em |= a != b ? (1 << (j >> 1)) : 0
            }
            edgeTable[i] = em
        }
        return edgeTable
    }
    
    public init(contourTracer: ContourTracer) {
        self.contourTracer = contourTracer
        dimensions = [contourTracer.G_DataWidth, contourTracer.G_DataHeight, contourTracer.G_DataDepth]
    }
    
    public func generate(material: Euclid.Polygon.Material = UIColor.blue) -> Mesh {
        
        var vertices : [Vector] = []
        var faces : [Euclid.Polygon] = []
        var n = 0
        var R = ([1, (dimensions[0] + 1), (dimensions[0] + 1) * (dimensions[1] + 1)])
        var grid = [Double](repeating: 0.0, count: 8)
        var bufNo = 1
        
        //Resize buffer if necessary
        var buffer = [Int](repeating: 0, count: max(4096, (R[2] * 2)))
        
        var isFirst = true
        
        //March over the voxel grid
        for z in 0 ..< dimensions[2] - 1 {
            
            if (!isFirst) {
                n += dimensions[0]
                bufNo ^= 1
                R[2] = -R[2]
            } else {
                isFirst = false
            }
        
            //m is the pointer into the buffer we are going to use.
            //This is slightly obtuse because javascript does not have good support for packed data structures, so we must use typed arrays :(
            //The contents of the buffer will be the indices of the vertices on the previous x/y slice of the volume
            var m = 1 + (dimensions[0] + 1) * (1 + bufNo * (dimensions[1] + 1))
          
            for y in 0 ..< dimensions[1] - 1 {
                if (y > 0) {
                    n += 1
                    m += 2
                }
                for x in 0 ..< dimensions[0] - 1 {
                    if (x > 0) {
                        n += 1
                        m += 1
                    }
                    
                    let expectedIndex = x + y * contourTracer.G_DataWidth + z * (contourTracer.G_DataWidth * contourTracer.G_DataHeight)
                    if (n != expectedIndex) {
                        NSLog("Unexpected index %d vs %d for (%d, %d, %d)", n, expectedIndex, x, y, z)
                    }
          
                    //Read in 8 field values around this vertex and store them in an array
                    //Also calculate 8-bit mask, like in marching cubes, so we can speed up sign checks later
                    var mask = 0, g = 0, idx = n;
                    for _ in 0 ..< 2 {
                        for _ in 0 ..< 2 {
                            for _ in 0 ..< 2 {
                                let p : Double
                                if idx < contourTracer.G_data1.count {
                                    p = Double(contourTracer.G_data1[idx]) - 50.0
                                } else {
                                    p = -50.0
                                }
                                grid[g] = p
                                mask |= (p < 0) ? (1 << g) : 0;
                                
                                g += 1
                                idx += 1
                            }
                            idx += dimensions[0] - 2
                        }
                        idx += dimensions[0] * (dimensions[1] - 2)
                    }

                    // Check for early termination if cell does not intersect boundary
                    if (mask == 0 || mask == 0xff) {
                        continue
                    }

                    //Sum up edge intersections
                    let edgeMask = SurfaceNet.edgeTable[mask]
                    var v = [0.0, 0.0, 0.0]
                    var eCount = 0
                      
                    //For every edge of the cube...
                    for i in 0 ..< 12 {

                        //Use edge mask to check if it is crossed
                        if ((edgeMask & (1 << i)) == 0) {
                            continue
                        }

                        //If it did, increment number of edge crossings
                        eCount += 1

                        //Now find the point of intersection
                        let e0 = SurfaceNet.cubeEdges[i << 1]       //Unpack vertices
                        let e1 = SurfaceNet.cubeEdges[(i << 1) + 1]
                        let g0 = grid[e0]                 //Unpack grid values
                        let g1 = grid[e1]
                        var t  = g0 - g1                 //Compute point of intersection
                        if (abs(t) > 1e-6) {
                            t = g0 / t
                        } else {
                            continue
                        }

                        //Interpolate vertices and add up intersections (this can be done without multiplying)
                        var k = 1
                        for j in 0 ..< 3 {
                            let a = e0 & k
                            let b = e1 & k
                            if (a != b) {
                                v[j] += a > 0 ? 1.0 - t : t
                            } else {
                                v[j] += a > 0 ? 1.0 : 0
                            }
                            k<<=1
                        }
                    }

                    //Now we just average the edge intersections and add them to coordinate
                    let s = 1.0 / Double(eCount)
                    
                    let position = [Double(x), Double(y), Double(z)]
                    for i in 0 ..< 3 {
                        v[i] = position[i] + s * v[i]
                    }

                    //Add vertex to buffer, store pointer to vertex index in buffer
                    buffer[m] = vertices.count
                    vertices.append(Vector(v))

                    //Now we need to add faces together, to do this we just loop over 3 basis components
                    for i in 0 ..< 3 {
                        //The first three entries of the edge_mask count the crossings along the edge
                        if ((edgeMask & (1 << i)) == 0) {
                            continue
                        }
                      
                        // i = axes we are point along.  iu, iv = orthogonal axes
                        let iu = (i + 1) % 3
                        let iv = (i + 2) % 3

                        //If we are on a boundary, skip it
                        if (position[iu] == 0 || position[iv] == 0) {
                            continue
                        }

                        //Otherwise, look up adjacent edges in buffer
                        let du = R[iu]
                        let dv = R[iv]

                        //Remember to flip orientation depending on the sign of the corner.
                        let vertexIndices : [Int]
                        if (mask & 1 > 0) {
                            vertexIndices = [buffer[m], buffer[m-du], buffer[m-du-dv], buffer[m-dv]]
                        } else {
                            vertexIndices = [buffer[m], buffer[m-dv], buffer[m-du-dv], buffer[m-du]]
                        }
                        let vertexPositions = vertexIndices.map { vertices[$0] }
                        
                        if let plane = Plane(points: vertexPositions), let face = Euclid.Polygon(vertexPositions.map { Vertex($0, plane.normal) }, material: material) {
                            faces.append(face)
                        }
                    }
                }
                n += 1
                m += 1
            }
            n += 1
            m += 2
        }
        
        return Mesh(faces)
    }
}
