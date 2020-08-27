//
//  Octree.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 16/08/2020.
//

import Foundation
import Euclid

fileprivate struct OctreeCoordinate {
    let x : Int
    let y : Int
    let z : Int
    let nodeSize : Int
    let nodeIndex : Int
}

fileprivate struct OctreeNode {
    
    fileprivate static let INVALID_NODE : Int16 = -2
    
    var marchingCubesCase : Int16 = -1   // -1 == invalid
    var intersectionPoints : [Vector] = [] // Is this the right way to do it? Or lists of 0..<1 ranges along specific edges?
    
    var childNodes : [Int] = []
    
    func merge(tree: Octree, coord: OctreeCoordinate) -> OctreeNode {
        guard !childNodes.isEmpty else {
            return OctreeNode(marchingCubesCase: 0)
        }
        
        let index = tree.grid.width * tree.grid.height * coord.z + tree.grid.width * coord.y + coord.x
                
        let neighbours = MarchingCubesSlice.findCellCorners(grid: tree.grid, x: coord.x, y: coord.y, z: coord.z, index: index, width: coord.nodeSize, height: coord.nodeSize, depth: coord.nodeSize)
        
        var marchingCubesCase : Int16 = 0
        for (vertexIndex, value) in neighbours.enumerated() {
            if (value >> VoxelGrid.dataBits != 0) {
                marchingCubesCase |= 1 << vertexIndex
            }
        }
        
        var intersectionPoints : [Vector] = []
        
        let edges = MarchingCubes.edgeTable[Int(marchingCubesCase)]
        for edgeIndex in 0 ..< 12 {
            let edgeMask = (1 << edgeIndex)
            if (edges & edgeMask > 0) {
                // The intersection on this edge will come from the corresponding edge from one of two children
                let childNode1 = childNodes[Octree.subEdges[edgeIndex].0]
                let childNode2 = childNodes[Octree.subEdges[edgeIndex].1]
                let childCase1 = Int(tree.nodes[childNode1].marchingCubesCase)
                let childCase2 = Int(tree.nodes[childNode2].marchingCubesCase)
                let childEdges1 = childCase1 > -1 ? MarchingCubes.edgeTable[childCase1] : 0
                let childEdges2 = childCase2 > -1 ? MarchingCubes.edgeTable[childCase2] : 0
                if (childEdges1 & edgeMask > 0) {
                    // Take intersection point from this child
                    var intersectionIndex = 0
                    var hasFoundIntersection = false
                    for childEdgeIndex in 0 ..< 12 {
                        if (childEdges1 & (1 << childEdgeIndex) > 0) {
                            if (childEdgeIndex == edgeIndex) {
                                intersectionPoints.append(tree.nodes[childNode1].intersectionPoints[intersectionIndex])
                                hasFoundIntersection = true
                                break
                            } else {
                                intersectionIndex += 1
                            }
                        }
                    }
                    assert(hasFoundIntersection)
                } else if (childEdges2 & edgeMask > 0) {
                    // Take intersection point from other child
                    var intersectionIndex = 0
                    var hasFoundIntersection = false
                    for childEdgeIndex in 0 ..< 12 {
                        if (childEdges2 & (1 << childEdgeIndex) > 0) {
                            if (childEdgeIndex == edgeIndex) {
                                intersectionPoints.append(tree.nodes[childNode2].intersectionPoints[intersectionIndex])
                                hasFoundIntersection = true
                                break
                            } else {
                                intersectionIndex += 1
                            }
                        }
                    }
                    assert(hasFoundIntersection)
                } else {
                    for m in 0 ..< 8 {
                        let childCase = Int(tree.nodes[childNodes[m]].marchingCubesCase)
                        let childEdges = childCase > -1 ? MarchingCubes.edgeTable[childCase] : 0
                        if (childEdges & edgeMask > 0) {
                            NSLog("Surprisingly, child %d has a matching edge", m)
                        }
                    }
                    
                    assert(false)
                }
            }
        }
        
        return OctreeNode(marchingCubesCase: marchingCubesCase, intersectionPoints: intersectionPoints, childNodes: self.childNodes)
    }
    
    func canMerge(tree: Octree, coord: OctreeCoordinate) -> Bool {
        guard childNodes.count > 0 else { return true }
        
        for child in childNodes {
            let childNode = tree.nodes[child]
            if childNode.marchingCubesCase == OctreeNode.INVALID_NODE ||
                (childNode.marchingCubesCase != -1 && MarchingCubes.surfaceCount[Int(childNode.marchingCubesCase)] > 1) {
                return false
            }
        }
        
        // Check all of the edges for multiple intersections
        let childEdges = childNodes.map { tree.nodes[$0].marchingCubesCase != -1 ? MarchingCubes.edgeTable[Int(tree.nodes[$0].marchingCubesCase)] : 0 }
        for (edgeIndex, childCubeIndices) in Octree.allEdges.enumerated() {
            for (firstChild, secondChild) in childCubeIndices {
                if (childEdges[firstChild] & (1 << edgeIndex) > 0) && (childEdges[secondChild] & (1 << edgeIndex) > 0) {
                    // Double intersection
                    return false
                }
            }
        }
        
        return true
    }
}

class Octree {
    
    private let depth : Int
    fileprivate var nodes : [OctreeNode]
    let grid : VoxelGrid
    
    static let allEdges = [
        [(0, 4)],                          // 0
        [(0, 1), (4, 5)],                  // 1
        [(0, 4), (1, 5)],                  // 2
        [(0, 1)],                          // 3
        [(0, 4), (2, 6)],                  // 4
        [(0, 1), (4, 5), (2, 3), (6, 7)],  // 5
        [(0, 4), (1, 5), (2, 6), (3, 7)],  // 6
        [(0, 1), (2, 3)]                   // 7
    ]
    
    static let allEdges2 = [
        [(0, 0), (0, 1), (4, 1)],
        [(0, 1), (0, 2), (1, 2)],
        [(0, 3), (0, 2), (4, 2)],
        [(0, 0), (0, 3), (1, 3)],
        [(0, 4), (0, 5), (4, 5)],
        [(0, 5), (0, 6), (1, 6)],
        [(0, 7), (0, 6), (4, 6)],
        [(0, 4), (0, 7), (1, 7)],
        [(0, 0), (0, 4), (2, 4)],
        [(0, 1), (0, 5), (2, 5)],
        [(0, 2), (0, 6), (2, 6)],
        [(0, 3), (0, 7), (2, 7)],
        [(1, 3), (1, 2), (5, 2)],
        [(1, 7), (1, 6), (5, 6)],
        [(1, 2), (1, 6), (3, 6)],
        [(1, 3), (1, 7), (3, 7)],
        [(2, 4), (2, 5), (6, 5)],
        [(2, 5), (2, 6), (3, 6)],
        [(2, 7), (2, 6), (6, 6)],
        [(2, 4), (2, 7), (3, 7)],
        [(3, 7), (3, 6), (7, 6)],
        [(4, 1), (4, 2), (5, 2)],
        [(4, 5), (4, 6), (5, 6)],
        [(4, 1), (4, 5), (6, 5)],
        [(4, 2), (4, 6), (6, 6)],
        [(5, 2), (5, 6), (7, 6)],
        [(6, 5), (6, 6), (7, 6)],
    ]
    
    // For each edge in a parent node, it could come from the corresponding edge of two of its children
    static let subEdges = [
        (0, 4), // 0
        (4, 5), // 1
        (1, 5), // 2
        (0, 1), // 3
        (2, 6), // 4
        (6, 7), // 5
        (3, 7), // 6
        (2, 3), // 7
        (0, 2), // 8
        (4, 6), // 9
        (5, 7), // 10
        (1, 3)  // 11
    ]
    
    public static func findAllEdges() {
        Swift.print("let allEdges = [")
        for cell in 0 ... 7 {
            let zz = cell / 4
            let yy = (cell - zz * 4) / 2
            let xx = cell % 2
            assert(cell == zz * 4 + yy * 2 + xx)
            
            for (vertexA, vertexB) in MarchingCubes.edgeVertices {
                // See which direction this edge runs, and therefore what the second cell to compare with should be
                let direction = (MarchingCubes.vertexOffsets[vertexB] - MarchingCubes.vertexOffsets[vertexA])
                let offset : Int
                let vertex1 : Int
                let vertex2 : Int
                let vertex3 : Int
                if (direction.x != 0) {
                    if (yy == 1 && MarchingCubes.vertexOffsets[vertexA].y == 0) ||
                        (zz == 1 && MarchingCubes.vertexOffsets[vertexA].z == 0) {
                        // Skip the internal edge
                        continue
                    }
                    
                    if (xx == 1) {
                        continue
                    }
                    
                    offset = 1
                    if (direction.x > 0) {
                        vertex1 = vertexA
                        vertex2 = vertexB
                        vertex3 = vertexB
                    } else {
                        vertex1 = vertexB
                        vertex2 = vertexA
                        vertex3 = vertexA
                    }
                } else if (direction.y != 0) {
                    if (xx == 1 && MarchingCubes.vertexOffsets[vertexA].x == 0) ||
                        (zz == 1 && MarchingCubes.vertexOffsets[vertexA].z == 0) {
                        // Skip the internal edge
                        continue
                    }
                    
                    if (yy == 1) {
                        continue
                    }
                    
                    offset = 2
                    if (direction.y > 0) {
                        vertex1 = vertexA
                        vertex2 = vertexB
                        vertex3 = vertexB
                    } else {
                        vertex1 = vertexB
                        vertex2 = vertexA
                        vertex3 = vertexA
                    }
                } else {
                    assert(direction.z != 0)
                    
                    if (yy == 1 && MarchingCubes.vertexOffsets[vertexA].y == 0) ||
                        (xx == 1 && MarchingCubes.vertexOffsets[vertexA].x == 0) {
                        // Skip the internal edge
                        continue
                    }
                    
                    if (zz == 1) {
                        continue
                    }
                                        
                    offset = 4
                    if (direction.z > 0) {
                        vertex1 = vertexA
                        vertex2 = vertexB
                        vertex3 = vertexB
                    } else {
                        vertex1 = vertexB
                        vertex2 = vertexA
                        vertex3 = vertexA
                    }
                }
            
                assert(cell + offset <= 7)
                Swift.print(String(format: "    [(%d, %d), (%d, %d), (%d, %d)],", cell, vertex1, cell, vertex2, cell + offset, vertex3))
            }
        }
        Swift.print("]")
    }
    
    init(grid: VoxelGrid) {
        self.grid = grid
        
        // The depth of the octree is the largest integer greater than or equal to the logarithm of the maximum of X, Y and Z.
        depth = Int(ceil(log2(Double(Swift.max(grid.width, grid.height, grid.depth)))))
        
        NSLog("Octree depth is %d", depth)
        
        nodes = [OctreeNode()]
    }
    
    public func insert(x: Int, y: Int, z: Int, marchingCubesCase: Int16, intersectionPoints: [Vector]) {
        insert(parentNodeIndex: 0, x: x, y: y, z: z, marchingCubesCase: marchingCubesCase, intersectionPoints: intersectionPoints, depth: depth)
    }
    
    private func insert(parentNodeIndex: Int, x: Int, y: Int, z: Int, marchingCubesCase: Int16, intersectionPoints: [Vector], depth: Int) {
        
        let maxSize = 1 << depth
        assert(x < maxSize && y < maxSize && z < maxSize)
        
        if (depth >= 1) {
            let mid = maxSize / 2
            let xx = (x >= mid) ? 1 : 0
            let yy = (y >= mid) ? 1 : 0
            let zz = (z >= mid) ? 1 : 0
            let index = zz * 4 + yy * 2 + xx
            
            if (nodes[parentNodeIndex].childNodes.isEmpty) {
                // Insert child nodes
                for _ in (0 ..< 8) {
                    nodes[parentNodeIndex].childNodes.append(addNode())
                }
            }
            insert(parentNodeIndex: nodes[parentNodeIndex].childNodes[index], x: x - xx * mid, y: y - yy * mid, z: z - zz * mid, marchingCubesCase: marchingCubesCase, intersectionPoints: intersectionPoints, depth: depth - 1)
        } else {
            // We expect each leaf node to only be populated once
            assert(nodes[parentNodeIndex].marchingCubesCase == -1)
            
            // This is the target node
            nodes[parentNodeIndex].marchingCubesCase = marchingCubesCase
            nodes[parentNodeIndex].intersectionPoints = intersectionPoints
        }
    }
    
    fileprivate func addNode() -> Int {
        let index = nodes.count
        nodes.append(OctreeNode())
        return index
    }
    
    public func decimateMesh(material : Euclid.Polygon.Material) -> Mesh {
        var polygons : [Euclid.Polygon] = []
        
        // Start by merging cells
        mergeCells()
        
        // Use a queue of node index & depth
        var queue = Queue<OctreeCoordinate>()
    
        // Start with root node
        queue.enqueue(OctreeCoordinate(x: 0, y: 0, z: 0, nodeSize: 1 << depth, nodeIndex: 0))

        // We're going to do a BFS top to bottom
        while !queue.isEmpty {
            let coord = queue.dequeue()!
            
            let cubeIndex = Int(nodes[coord.nodeIndex].marchingCubesCase)
            if (cubeIndex != OctreeNode.INVALID_NODE) {
                
                guard cubeIndex != -1 else { continue }
                    
                let edges = MarchingCubes.edgeTable[cubeIndex]
                var intersectionPoints : [Vector] = []
                var n = 0
                for edgeIndex in (0 ..< 12) {
                    if (edges & (1 << edgeIndex) > 0) {
                        intersectionPoints.append(nodes[coord.nodeIndex].intersectionPoints[n])
                        n += 1
                    } else {
                        intersectionPoints.append(Vector.zero)
                    }
                }
                
                // Output triangles
                for n in stride(from: 0, to: MarchingCubes.triTable[cubeIndex].count, by: 3) {
                    
                    let positions = [
                        intersectionPoints[MarchingCubes.triTable[cubeIndex][n + 2]],
                        intersectionPoints[MarchingCubes.triTable[cubeIndex][n + 1]],
                        intersectionPoints[MarchingCubes.triTable[cubeIndex][n]]
                    ]
                    
                    let plane = Plane(points: positions)
                    
                    if let poly = Polygon(positions.map { Vertex($0, plane?.normal ?? Vector.zero) }, material: material) {
                        polygons.append(poly)
                    }
                }
                
            } else {
                // Navigate to children
                let childSize = coord.nodeSize >> 1
                
                for (childIndex, child) in nodes[coord.nodeIndex].childNodes.enumerated() {
                    let zz = childIndex / 4
                    let yy = (childIndex - zz * 4) / 2
                    let xx = childIndex % 2
                    assert(childIndex == zz * 4 + yy * 2 + xx)
                    
                    queue.enqueue(OctreeCoordinate(x: coord.x + xx * childSize, y: coord.y + yy * childSize, z: coord.z + zz * childSize, nodeSize: childSize, nodeIndex: child))
                }
            }
        }
        
        return Mesh(polygons)
    }
    
    private func mergeCells() {
        var stack : [OctreeCoordinate] = []
        
        // Use a queue of node index & depth
        var queue = Queue<OctreeCoordinate>()
    
        // Start with root node
        queue.enqueue(OctreeCoordinate(x: 0, y: 0, z: 0, nodeSize: 1 << depth, nodeIndex: 0))

        // We're going to do a BFS top to bottom, to populate a stack
        // which then allows us to visit them bottom to top
        while !queue.isEmpty {
            let coord = queue.dequeue()!
            
            // When we reach the level above the bottom, stop iterating and start merging
            if (coord.nodeSize == 2) {
                assert(nodes[coord.nodeIndex].childNodes.allSatisfy { nodes[$0].childNodes.isEmpty })
                
            } else {
                        
                guard !nodes[coord.nodeIndex].childNodes.isEmpty else { continue }
                
                assert(coord.nodeSize >= 4)
                let childSize = coord.nodeSize >> 1
                
                for (childIndex, child) in nodes[coord.nodeIndex].childNodes.enumerated() {
                    let zz = childIndex / 4
                    let yy = (childIndex - zz * 4) / 2
                    let xx = childIndex % 2
                    assert(childIndex == zz * 4 + yy * 2 + xx)
                    
                    queue.enqueue(OctreeCoordinate(x: coord.x + xx * childSize, y: coord.y + yy * childSize, z: coord.z + zz * childSize, nodeSize: childSize, nodeIndex: child))
                }
                
            }
            
            stack.append(coord)
        }
        
        while !stack.isEmpty {
            let coord = stack.popLast()!

            let node = nodes[coord.nodeIndex]
            if (node.canMerge(tree: self, coord: coord)) {
                // Merge this node
                nodes[coord.nodeIndex] = node.merge(tree: self, coord: coord)
            } else {
                // Mark this node as invalid and delete its grandchildren
                invalidateNode(index: coord.nodeIndex)
            }
        }
    }
    
    private func invalidateNode(index: Int) {
        nodes[index].marchingCubesCase = OctreeNode.INVALID_NODE
        return
        // Delete all children below those with a valid case number
        var queue = Queue<Int>()
        for childNode in nodes[index].childNodes {
            if (nodes[childNode].marchingCubesCase >= 0) {
                queue.enqueue(childNode)
            }
        }
        while !queue.isEmpty {
            let childIndex = queue.dequeue()!
            for childNode in nodes[childIndex].childNodes {
                if (nodes[childNode].marchingCubesCase >= 0) {
                    nodes[childNode] = OctreeNode(marchingCubesCase: OctreeNode.INVALID_NODE, intersectionPoints: [], childNodes: [])
                    queue.enqueue(childNode)
                }
            }
        }
    }
}
