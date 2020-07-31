//
//  DualContourer.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 27/07/2020.
//  Ported from https://github.com/nickgildea/fast_dual_contouring by Nick Gildea
//

import Foundation
import Euclid

struct EdgeInfo {
    public let pos : Vector
    public let normal : Vector
    public let winding : Bool
}

private struct Position3D : Hashable {
    let x : Int
    let y : Int
    let z : Int
    
    static let zero = Position3D(0, 0, 0)
    
    init(_ x : Int, _ y : Int, _ z : Int) {
        self.x = x
        self.y = y
        self.z = z
    }
}

extension Vector {
    static func interpolate(_ v1 : Vector, _ v2 : Vector, _ p : Double) -> Vector {
        let complement = 1 - p
        return v1 * complement + v2 * p
    }
    
    fileprivate init(_ position : Position3D) {
        self.init(Double(position.x), Double(position.y), Double(position.z))
    }
}

private struct PositionAndAxis : Hashable {
    let position : Position3D
    let axis : Int
}

private func -(left: Position3D, right: Position3D) -> Position3D {
    return Position3D(left.x - right.x, left.y - right.y, left.z - right.z)
}

private func +(left: Position3D, right: Position3D) -> Position3D {
    return Position3D(left.x + right.x, left.y + right.y, left.z + right.z)
}

public class DualContourer {
    
    static let THRESHOLD : CUnsignedChar = 50
    
    static let AXIS_OFFSET = [
        Vector(1, 0, 0),
        Vector(0, 1, 0),
        Vector(0, 0, 1)
    ]
    
    /// Equivalent of AXIS_OFFSET except it tells us what to add to the data set index
    private let axisIndexOffset : [Int]

    // ----------------------------------------------------------------------------

    private static let EDGE_NODE_OFFSETS = [
        Position3D.zero, Position3D(0, 0, 1), Position3D(0, 1, 0), Position3D(0, 1, 1),
        Position3D.zero, Position3D(1, 0, 0), Position3D(0, 0, 1), Position3D(1, 0, 1),
        Position3D.zero, Position3D(0, 1, 0), Position3D(1, 0, 0), Position3D(1, 1, 0),
    ]

    // ----------------------------------------------------------------------------

    // The two lookup tables below were calculated by expanding the IDs into 3d coordinates
    // performing the calcuations in 3d space and then converting back into the compact form
    // and subtracting the base voxel ID. Use of this lookup table means those calculations
    // can be avoided at run-time.

    static let ENCODED_EDGE_NODE_OFFSETS = [
        0x00000000,
        0x00100000,
        0x00000400,
        0x00100400,
        0x00000000,
        0x00000001,
        0x00100000,
        0x00100001,
        0x00000000,
        0x00000400,
        0x00000001,
        0x00000401,
    ]

    static let ENCODED_EDGE_OFFSETS = [
        0x00000000,
        0x00100000,
        0x00000400,
        0x00100400,
        0x40000000,
        0x40100000,
        0x40000001,
        0x40100001,
        0x80000000,
        0x80000400,
        0x80000001,
        0x80000401,
    ]

    private let contourTracer : ContourTracer
    
    private var activeEdges : [PositionAndAxis : EdgeInfo] = [:]
    private var activeVoxels = Set<Position3D>()
    private var voxelIndexMap : [Position3D: Int] = [:]
    
    public init(contourTracer: ContourTracer) {
        self.contourTracer = contourTracer
        
        axisIndexOffset = [1, contourTracer.G_DataWidth, contourTracer.G_DataWidth * contourTracer.G_DataHeight]
    }

    // ----------------------------------------------------------------------------

    private static func encodeAxisUniqueID(axis : Int, x : Int, y : Int, z : Int) -> Int {
        return (x << 0) | (y << 10) | (z << 20) | (axis << 30)
    }
    
//    private func findIntersection(_ p0 : Vector, _ p1 : Vector) -> Double {
//        let FIND_EDGE_INFO_STEPS = 16
//        let FIND_EDGE_INFO_INCREMENT = 1.0 / Double(FIND_EDGE_INFO_STEPS)
//
//        var minValue = Double.greatestFiniteMagnitude
//        var currentT = 0.0
//        var t = 0.0
//        for _ in 0 ..< FIND_EDGE_INFO_STEPS {
//            let p = Vector.interpolate(p0, p1, currentT)
//            let d = abs(density(p))
//            if (d < minValue) {
//                t = currentT
//                minValue = d
//            }
//
//            currentT += FIND_EDGE_INFO_INCREMENT
//        }
//
//        return t
//    }

    // ----------------------------------------------------------------------------

//    func findNormal(_ pos : Vector) -> Vector {
//        let H = 0.001
//        /*Vector(
//            Density(config, pos + vec4(H, 0.f, 0.f, 0.f)) - Density(config, pos - vec4(H, 0.f, 0.f, 0.f)),
//            Density(config, pos + vec4(0.f, H, 0.f, 0.f)) - Density(config, pos - vec4(0.f, H, 0.f, 0.f)),
//            Density(config, pos + vec4(0.f, 0.f, H, 0.f)) - Density(config, pos - vec4(0.f, 0.f, H, 0.f)),
//            0.f).normalize()*/
//    }
    
    func findPositionAndNormal(_ p : Vector, _ q : Vector) -> (Vector, Vector) {
//        let t = findIntersection(p, q)
//        let pos = Vector.interpolate(p, q, t) //, 1.f);
        let pos = Vector.interpolate(p, q, 0.5) //, 1.f);

        let normal = Vector.zero // findNormal(pos)
        
        return (pos, normal)
    }
    
    func findActiveVoxels() {
        var k = 0
        for z in 0 ..< contourTracer.G_DataDepth {
            for y in 0 ..< contourTracer.G_DataHeight {
                for x in 0 ..< contourTracer.G_DataWidth {
                    let idxPos = Position3D(x, y, z)
                    let p = Vector(Double(x), Double(y), Double(z))//, 1.f);

                    for axis in 0 ..< 3 {
                        let q = p + DualContourer.AXIS_OFFSET[axis]
                        let indexOffset = axisIndexOffset[axis]

                        let pDensity = contourTracer.G_data1[k]
                        let qDensity = contourTracer.G_data1[k + indexOffset]

                        let zeroCrossing =
                            pDensity >= DualContourer.THRESHOLD && qDensity < DualContourer.THRESHOLD ||
                            pDensity < DualContourer.THRESHOLD && qDensity >= DualContourer.THRESHOLD
                        
                        if (!zeroCrossing) {
                            continue
                        }
                        
                        let (pos, normal) = findPositionAndNormal(p, q)

                        let info = EdgeInfo(pos: pos, normal: normal, winding: pDensity >= DualContourer.THRESHOLD)

                        let code = PositionAndAxis(position: idxPos, axis: axis)
                        activeEdges[code] = info

                        for i in 0 ..< 4 {
                            let nodeIdxPos = idxPos - DualContourer.EDGE_NODE_OFFSETS[axis * 4 + i]
                            activeVoxels.insert(nodeIdxPos)
                        }
                    }
                    
                    k += 1
                }
            }
        }
    }

    // ----------------------------------------------------------------------------

    func generateVertexData() -> [Vertex] {
        var vertices : [Vertex] = []
        
        for voxelID in activeVoxels {
            var localVertices : [Vertex] = []
            for i in 0 ..< 12 {
                let edgeIDPosition = voxelID + DualContourer.EDGE_NODE_OFFSETS[i]
                let edgeIDAxis = i / 4
                
                let edgeID = PositionAndAxis(position: edgeIDPosition, axis: edgeIDAxis)
                if let info = activeEdges[edgeID] {
                    localVertices.append(Vertex(info.pos, info.normal))
                }
            }

            let nodePos = Vector(voxelID) // qef_solve_from_points_4d(localVertices)

            var nodeNormal = Vector.zero
            for vertex in localVertices {
                nodeNormal = nodeNormal + vertex.normal
            }
            nodeNormal = nodeNormal * 1.0 / Double(localVertices.count)

            voxelIndexMap[voxelID] = vertices.count

            vertices.append(Vertex(nodePos, nodeNormal))
        }

        return vertices
    }

    // ----------------------------------------------------------------------------

    func generateTriangles(vertices: [Vertex], material: Euclid.Polygon.Material) -> [Euclid.Polygon] {
        var triangles : [Euclid.Polygon] = []

        for pair in activeEdges {
            let info = pair.value
            let edge = pair.key

            let basePos = edge.position
            let axis = edge.axis

            let voxelIDs = [
                basePos - DualContourer.EDGE_NODE_OFFSETS[(axis * 4 + 0)],
                basePos - DualContourer.EDGE_NODE_OFFSETS[(axis * 4 + 1)],
                basePos - DualContourer.EDGE_NODE_OFFSETS[(axis * 4 + 2)],
                basePos - DualContourer.EDGE_NODE_OFFSETS[(axis * 4 + 3)]
            ]

            // attempt to find the 4 voxels which share this edge
            var edgeVoxels : [Int] = []
            for voxelID in voxelIDs {
                if let vertexIndex = voxelIndexMap[voxelID] {
                    edgeVoxels.append(vertexIndex)
                }
            }

            // we can only generate a quad (or two triangles) if all 4 are found
            guard edgeVoxels.count >= 4 else { continue }

            if (info.winding) {
                if let tri1 = Euclid.Polygon([0, 1, 3].map({ vertices[edgeVoxels[$0]] }), material: material) {
                    triangles.append(tri1)
                }
                if let tri2 = Euclid.Polygon([0, 3, 2].map({ vertices[edgeVoxels[$0]] }), material: material) {
                    triangles.append(tri2)
                }
            } else {
                if let tri1 = Euclid.Polygon([0, 3, 1].map({ vertices[edgeVoxels[$0]] }), material: material) {
                    triangles.append(tri1)
                }
                if let tri2 = Euclid.Polygon([0, 2, 3].map({ vertices[edgeVoxels[$0]] }), material: material) {
                    triangles.append(tri2)
                }
            }
        }
        return triangles
    }

    // ----------------------------------------------------------------------------

    public func generateMesh(material: Euclid.Polygon.Material = UIColor.blue) -> Mesh {
        findActiveVoxels()
        
        let vertices = generateVertexData()

        let triangles = generateTriangles(vertices: vertices, material: material)

        NSLog("mesh: %d vertices, %d polygon(s)\n", vertices.count, triangles.count)

        return Mesh(triangles)
    }
}
