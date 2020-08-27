//
//  AdaptiveSkeletonClimber.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 08/07/2020.
//

import Euclid

enum VoxelAxis : Int {
    case none = 0
    case xy = 1
    case yz = 2
    case multiple = 3
}

public class VoxelGrid {

    static let G_Threshold = 50.0
    
    public static let dataBits = 3    
    
    public var data : [Int]
    public let width : Int
    public let height : Int
    public let depth : Int
    
    internal var seedCells : Set<Int> = Set([])
    
    internal var rootCuboids : [Cuboid] = []
    
    public init(width : Int, height : Int, depth : Int) {
        self.width = width
        self.height = height
        self.depth = depth
        self.data = [Int](repeating: 0, count: width * height * depth)
    }
    
    public func cellIndex(x: Int, y: Int, z: Int) -> Int {
        return x + y * width + z * (width * height)
    }
    
    public func addSeed(x: Int, y: Int, z: Int) {
        addSeed(cellIndex(x: x, y: y, z: z))
    }
    
    public func addSeed(_ index : Int) {
        guard index < data.count else { return }
        seedCells.insert(index)
    }
    
    public func positionFromIndex(_ index: Int) -> (Int, Int, Int) {
        let z = Int(index / (width * height))
        let zLayerStart = z * (width * height)
        let y = Int((index - zLayerStart) / width)
        let yRowStart = zLayerStart + y * width
        let x = index - yRowStart
        return (x, y, z)
    }
    
    public var seeds : [(Int, Int, Int)] {
        var results : [(Int, Int, Int)] = []
        for index in self.seedCells {
            results.append(positionFromIndex(index))
        }
        return results
    }
    
    public func generateMesh() -> Mesh {
        return Mesh([])
    }
}
