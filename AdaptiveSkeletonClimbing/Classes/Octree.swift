//
//  Octree.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 16/08/2020.
//

import Foundation
import Euclid

struct OctreeNode {
    
    private let INVALID_NODE : Int16 = -2
    
    var marchingCubesCase : Int16 = -1   // -1 == invalid
    var intersectionPoints : [[Vector]] = [] // Is this the right way to do it? Or lists of 0..<1 ranges along specific edges?
    
    var childNodes : [Int] = []
    
    mutating func merge(tree: Octree) {
        self.marchingCubesCase = 0
        self.intersectionPoints = childNodes.flatMap { tree.nodes[$0].intersectionPoints }
    }
    
    func canMerge(tree: Octree) -> Bool {
        guard childNodes.count > 0 else { return true }
        
        for child in childNodes {
            let childNode = tree.nodes[child]
            if childNode.marchingCubesCase == INVALID_NODE ||
                (childNode.marchingCubesCase != -1 && !MarchingCubes.simpleCases[Int(childNode.marchingCubesCase)]) {
                return false
            }
        }
        
        // Check all of the edges for multiple intersections
        for edge in Octree.allEdges {
            var hasChanged = false
            var value = false
            for (n, (childIndex, vertexIndex)) in edge.enumerated() {
                let currentValue = (tree.nodes[childNodes[childIndex]].marchingCubesCase & (1 << vertexIndex) > 0)
                if (n == 0) {
                    value = currentValue
                } else {
                    if (currentValue != value) {
                        guard !hasChanged else {
                            return false
                        }
                        hasChanged = true
                    }
                }
            }
        }
        
        return true
    }
    
    mutating func invalidate() {
        self.marchingCubesCase = INVALID_NODE
        self.childNodes = []
    }
}

struct OctreeNodeIterator : IteratorProtocol {
    let tree : Octree
    let depth : Int
    
    
    
    mutating func next() -> OctreeNode? {
        return nil
    }
}

class Octree : Sequence {
    
    private let depth : Int
    fileprivate var nodes : [OctreeNode]
    
    static let allEdges = [
        [(0, 1), (0, 0), (4, 0)],
        [(0, 1), (0, 2), (1, 2)],
        [(0, 2), (0, 3), (4, 3)],
        [(0, 0), (0, 3), (1, 3)],
        [(0, 5), (0, 4), (4, 4)],
        [(0, 5), (0, 6), (1, 6)],
        [(0, 6), (0, 7), (4, 7)],
        [(0, 4), (0, 7), (1, 7)],
        [(0, 0), (0, 4), (2, 4)],
        [(0, 1), (0, 5), (2, 5)],
        [(0, 2), (0, 6), (2, 6)],
        [(0, 3), (0, 7), (2, 7)],
        [(1, 2), (1, 3), (5, 3)],
        [(1, 6), (1, 7), (5, 7)],
        [(1, 2), (1, 6), (3, 6)],
        [(1, 3), (1, 7), (3, 7)],
        [(2, 5), (2, 4), (6, 4)],
        [(2, 5), (2, 6), (3, 6)],
        [(2, 6), (2, 7), (6, 7)],
        [(2, 4), (2, 7), (3, 7)],
        [(3, 6), (3, 7), (7, 7)],
        [(4, 0), (4, 3), (5, 3)],
        [(4, 4), (4, 7), (5, 7)],
        [(4, 0), (4, 4), (6, 4)],
        [(4, 3), (4, 7), (6, 7)],
        [(5, 3), (5, 7), (7, 7)],
        [(6, 4), (6, 7), (7, 7)],
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
                        (zz == 1 && MarchingCubes.vertexOffsets[vertexA].z == -1) {
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
                        (zz == 1 && MarchingCubes.vertexOffsets[vertexA].z == -1) {
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
    
    private struct OctreeCoordinate {
        let x : Int
        let y : Int
        let z : Int
        let depth : Int
        let nodeIndex : Int
    }
    
    init(grid: VoxelGrid) {
        // The depth of the octree is the largest integer greater than or equal to the logarithm of the maximum of X, Y and Z.
        depth = Int(ceil(log2(Double(Swift.max(grid.width, grid.height, grid.depth)))))
        
        NSLog("Octree depth is %d", depth)
        
        nodes = [OctreeNode()]
    }
    
    public func insert(x: Int, y: Int, z: Int, marchingCubesCase: Int16, intersectionPoints: [[Vector]]) {
        insert(parentNodeIndex: 0, x: x, y: y, z: z, marchingCubesCase: marchingCubesCase, intersectionPoints: intersectionPoints, depth: depth)
    }
    
    private func insert(parentNodeIndex: Int, x: Int, y: Int, z: Int, marchingCubesCase: Int16, intersectionPoints: [[Vector]], depth: Int) {
        
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
    
    public func makeIterator() -> OctreeNodeIterator {
        return OctreeNodeIterator(tree: self, depth: depth - 1)
    }
    
    fileprivate func addNode() -> Int {
        let index = nodes.count
        nodes.append(OctreeNode())
        return index
    }
    
    public func mergeCells() {
        var stack : [OctreeCoordinate] = []
        
        // Use a queue of node index & depth
        var queue = Queue<OctreeCoordinate>()
    
        // Start with root node
        queue.enqueue(OctreeCoordinate(x: 0, y: 0, z: 0, depth: 0, nodeIndex: 0))

        // We're going to do a BFS top to bottom, to populate a stack
        // which then allows us to visit them bottom to top
        while !queue.isEmpty {
            let coord = queue.dequeue()!
            
            // When we reach the level above the bottom, stop iterating and start merging
            if (coord.depth == self.depth - 1) {
                assert(nodes[coord.nodeIndex].childNodes.allSatisfy { nodes[$0].childNodes.isEmpty })
                
            } else {
                        
                guard !nodes[coord.nodeIndex].childNodes.isEmpty else { continue }
                
                assert((self.depth - coord.depth - 2) >= 0)
                let childSize = 1 << (self.depth - coord.depth - 2)
                
                for (childIndex, child) in nodes[coord.nodeIndex].childNodes.enumerated() {
                    //let childIndex = zz * 4 + yy * 2 + xx
                    let zz = childIndex / 4
                    let yy = (childIndex - zz * 4) / 2
                    let xx = childIndex % 2
                    assert(childIndex == zz * 4 + yy * 2 + xx)
                    
                    queue.enqueue(OctreeCoordinate(x: coord.x + xx * childSize, y: coord.y + yy * childSize, z: coord.z + zz * childSize, depth: coord.depth + 1, nodeIndex: child))
                }
                
            }
            
            stack.append(coord)
        }
        
        while !stack.isEmpty {
            let coord = stack.popLast()!
            
//            0.0, 0.3, 1.3       [0, 0, 3]   // Horizontal lines are all +1 for the final vertex
//            4.0, 4.3, 5.3       [4, 0, 3]
//
//            0.1, 0.2, 1.2       [0, 1, 2]
//
//            0.5, 0.6, 1.6       [0, 5, 6]
//            2.5, 2.6, 3.6       [2, 5, 6]
//
//            0.4, 0.7, 1.7       [0, 4, 7]
//            4.4, 4.7, 5.7       [4, 4, 7]
//            2.4, 2.7, 3.7       [2, 4, 7]
//            6.4, 6.7, 7.7       [6, 4, 7]
            
            
                        
            
            
            var node = nodes[coord.nodeIndex]
            if (node.canMerge(tree: self)) {
                // Merge this node
                node.merge(tree: self)
            } else {
                // Mark this node as invalid and delete its children
                node.invalidate()
            }
        }
    }
}
