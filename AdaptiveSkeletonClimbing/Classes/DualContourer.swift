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

extension Vector {
    static func interpolate(_ v1 : Vector, _ v2 : Vector, _ p : Double) -> Vector {
        let complement = 1 - p
        return v1 * complement + v2 * p
    }
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

private struct PositionAndAxis : Hashable {
    let position : Position3D
    let axis : Int
}

private func -(left: Position3D, right: Position3D) -> Position3D {
    return Position3D(left.x - right.x, left.y - right.y, left.z - right.z)
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
        [Position3D.zero, Position3D(0, 0, 1), Position3D(0, 1, 0), Position3D(0, 1, 1) ],
        [Position3D.zero, Position3D(1, 0, 0), Position3D(0, 0, 1), Position3D(1, 0, 1) ],
        [Position3D.zero, Position3D(0, 1, 0), Position3D(1, 0, 0), Position3D(1, 1, 0) ],
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
    
    public func generate(material: Euclid.Polygon.Material = UIColor.blue) -> Mesh {
        
    }

    // ----------------------------------------------------------------------------

    private static func encodeAxisUniqueID(axis : Int, x : Int, y : Int, z : Int) -> Int {
        return (x << 0) | (y << 10) | (z << 20) | (axis << 30)
    }
    
    private func density(_ p : Vector) -> Double {
        
    }
    
    private func findIntersection(_ p0 : Vector, _ p1 : Vector) -> Double {
        let FIND_EDGE_INFO_STEPS = 16
        let FIND_EDGE_INFO_INCREMENT = 1.0 / Double(FIND_EDGE_INFO_STEPS)

        var minValue = Double.greatestFiniteMagnitude
        var currentT = 0.0
        var t = 0.0
        for _ in 0 ..< FIND_EDGE_INFO_STEPS {
            let p = Vector.interpolate(p0, p1, currentT)
            let d = abs(density(p))
            if (d < minValue) {
                t = currentT
                minValue = d
            }

            currentT += FIND_EDGE_INFO_INCREMENT
        }

        return t
    }

    // ----------------------------------------------------------------------------

    func findNormal(_ pos : Vector) -> Vector {
        let H = 0.001
        /*Vector(
            Density(config, pos + vec4(H, 0.f, 0.f, 0.f)) - Density(config, pos - vec4(H, 0.f, 0.f, 0.f)),
            Density(config, pos + vec4(0.f, H, 0.f, 0.f)) - Density(config, pos - vec4(0.f, H, 0.f, 0.f)),
            Density(config, pos + vec4(0.f, 0.f, H, 0.f)) - Density(config, pos - vec4(0.f, 0.f, H, 0.f)),
            0.f).normalize()*/
    }
    
    func findPositionAndNormal(_ p : Vector, _ q : Vector) -> (Vector, Vector) {
        let t = findIntersection(p, q)
        let pos = Vector.interpolate(p, q, t) //, 1.f);

        let normal = findNormal(pos)
        
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

                        let edgeNodes = DualContourer.EDGE_NODE_OFFSETS[axis]
                        for i in 0 ..< 4 {
                            let nodeIdxPos = idxPos - edgeNodes[i]
                            activeVoxels.insert(nodeIdxPos)
                        }
                    }
                    
                    k += 1
                }
            }
        }
    }

    // ----------------------------------------------------------------------------

    static void GenerateVertexData(
        const VoxelIDSet& voxels,
        const EdgeInfoMap& edges,
        VoxelIndexMap& vertexIndices,
        MeshBuffer* buffer)
    {
        MeshVertex* vert = &buffer->vertices[0];

        int idxCounter = 0;
        for (const auto& voxelID: voxels)
        {
            ALIGN16 vec4 p[12];
            ALIGN16 vec4 n[12];

            int idx = 0;
            for (int i = 0; i < 12; i++)
            {
                const auto edgeID = voxelID + ENCODED_EDGE_OFFSETS[i];
                const auto iter = edges.find(edgeID);

                if (iter != end(edges))
                {
                    const auto& info = iter->second;
                    const vec4 pos = info.pos;
                    const vec4 normal = info.normal;

                    p[idx] = pos;
                    n[idx] = normal;
                    idx++;
                }
            }

            ALIGN16 vec4 nodePos;
            qef_solve_from_points_4d(&p[0].x, &n[0].x, idx, &nodePos.x);

            vec4 nodeNormal;
            for (int i = 0; i < idx; i++)
            {
                nodeNormal += n[i];
            }
            nodeNormal *= (1.f / (float)idx);

            vertexIndices[voxelID] = idxCounter++;

            buffer->numVertices++;
            vert->xyz = nodePos;
            vert->normal = nodeNormal;
            vert++;
        }

    }

    // ----------------------------------------------------------------------------

    static void GenerateTriangles(
        const EdgeInfoMap& edges,
        const VoxelIndexMap& vertexIndices,
        MeshBuffer* buffer)
    {
        MeshTriangle* tri = &buffer->triangles[0];

        for (const auto& pair: edges)
        {
            const auto& edge = pair.first;
            const auto& info = pair.second;

            const ivec4 basePos = DecodeVoxelUniqueID(edge);
            const int axis = (edge >> 30) & 0xff;

            const int nodeID = edge & ~0xc0000000;
            const uint32_t voxelIDs[4] =
            {
                nodeID - ENCODED_EDGE_NODE_OFFSETS[axis * 4 + 0],
                nodeID - ENCODED_EDGE_NODE_OFFSETS[axis * 4 + 1],
                nodeID - ENCODED_EDGE_NODE_OFFSETS[axis * 4 + 2],
                nodeID - ENCODED_EDGE_NODE_OFFSETS[axis * 4 + 3],
            };

            // attempt to find the 4 voxels which share this edge
            int edgeVoxels[4];
            int numFoundVoxels = 0;
            for (int i = 0; i < 4; i++)
            {
                const auto iter = vertexIndices.find(voxelIDs[i]);
                if (iter != end(vertexIndices))
                {
                    edgeVoxels[numFoundVoxels++] = iter->second;
                }
            }

            // we can only generate a quad (or two triangles) if all 4 are found
            if (numFoundVoxels < 4)
            {
                continue;
            }

            if (info.winding)
            {
                tri->indices_[0] = edgeVoxels[0];
                tri->indices_[1] = edgeVoxels[1];
                tri->indices_[2] = edgeVoxels[3];
                tri++;

                tri->indices_[0] = edgeVoxels[0];
                tri->indices_[1] = edgeVoxels[3];
                tri->indices_[2] = edgeVoxels[2];
                tri++;
            }
            else
            {
                tri->indices_[0] = edgeVoxels[0];
                tri->indices_[1] = edgeVoxels[3];
                tri->indices_[2] = edgeVoxels[1];
                tri++;

                tri->indices_[0] = edgeVoxels[0];
                tri->indices_[1] = edgeVoxels[2];
                tri->indices_[2] = edgeVoxels[3];
                tri++;
            }

            buffer->numTriangles += 2;
        }
    }

    // ----------------------------------------------------------------------------

    MeshBuffer* GenerateMesh(const SuperPrimitiveConfig& config)
    {
        VoxelIDSet activeVoxels;
        EdgeInfoMap activeEdges;

        FindActiveVoxels(config, activeVoxels, activeEdges);

        MeshBuffer* buffer = new MeshBuffer;
        buffer->vertices = (MeshVertex*)malloc(activeVoxels.size() * sizeof(MeshVertex));
        buffer->numVertices = 0;

        VoxelIndexMap vertexIndices;
        GenerateVertexData(activeVoxels, activeEdges, vertexIndices, buffer);

        buffer->triangles = (MeshTriangle*)malloc(2 * activeEdges.size() * sizeof(MeshTriangle));
        buffer->numTriangles = 0;
        GenerateTriangles(activeEdges, vertexIndices, buffer);

        printf("mesh: %d %d\n", buffer->numVertices, buffer->numTriangles);

        return buffer;
    }
}
