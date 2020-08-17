//
//  Octree.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 16/08/2020.
//

import Foundation
import Euclid

struct OctreeNode {
    
    var marchingCubesCase : Int16 = -1   // -1 == invalid
    var intersectionPoints : [[Vector]] = [] // Is this the right way to do it? Or lists of 0..<1 ranges along specific edges?
    
    var childNodes : [Int] = []
        
    fileprivate mutating func insert(tree: Octree, x: Int, y: Int, z: Int, marchingCubesCase: Int16, intersectionPoints: [[Vector]], depth: Int) {
        
        assert(x < depth && y < depth && z < depth)
        
        if (depth > 1) {
            let mid = depth / 2
            let xx = (x >= mid) ? 1 : 0
            let yy = (y >= mid) ? 1 : 0
            let zz = (z >= mid) ? 1 : 0
            let index = zz * 4 + yy * 2 + xx
            
            if (childNodes.isEmpty) {
                // Insert child nodes
                for _ in (0 ..< 8) {
                    childNodes.append(tree.addNode())
                }
            }
            tree.nodes[childNodes[index]].insert(tree: tree, x: x - xx * mid, y: y - yy * mid, z: z - zz * mid, marchingCubesCase: marchingCubesCase, intersectionPoints: intersectionPoints, depth: mid)
        } else {
            // We expect each leaf node to only be populated once
            assert(self.marchingCubesCase == -1)
            
            // This is the target node
            self.marchingCubesCase = marchingCubesCase
            self.intersectionPoints = intersectionPoints
        }
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
    
    init(grid: VoxelGrid) {
        // The depth of the octree is the largest integer greater than or equal to the logarithm of the maximum of X, Y and Z.
        depth = Int(ceil(log2(Double(Swift.max(grid.width, grid.height, grid.depth)))))
        
        NSLog("Octree depth is %d", depth)
        
        nodes = [OctreeNode()]
    }
    
    public func insert(x: Int, y: Int, z: Int, marchingCubesCase: Int16, intersectionPoints: [[Vector]]) {
        nodes[0].insert(tree: self, x: x, y: y, z: z, marchingCubesCase: marchingCubesCase, intersectionPoints: intersectionPoints, depth: depth)
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
        var stack : [Int] = []
        
        // Use a queue of node index & depth
        var queue = Queue<(Int, Int)>()
    
        // Start with root node
        queue.enqueue((0, 0))

        // We're going to do a BFS top to bottom, to populate a stack
        // which then allows us to visit them bottom to top
        while !queue.isEmpty {
            let (nodeIndex, depth) = queue.dequeue()!
            
            // When we reach the level above the bottom, stop iterating and start merging
            if (depth == self.depth - 1) {
                assert(nodes[nodeIndex].childNodes.allSatisfy { nodes[$0].childNodes.isEmpty })
                
                
            }
                        
            guard !nodes[nodeIndex].childNodes.isEmpty else { continue }
            
            for child in nodes[nodeIndex].childNodes {
                queue.enqueue((child, depth + 1))
            }
            
            stack.append(nodeIndex)
        }
    }
}
