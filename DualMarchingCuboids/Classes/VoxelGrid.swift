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
    
    internal var seedCells = Queue<Int>()
    public var cuboids : [Int: Cuboid] = [:]
    
    public init(width : Int, height : Int, depth : Int) {
        self.width = width
        self.height = height
        self.depth = depth
        self.data = [Int](repeating: 0, count: width * height * depth)
    }
    
    public func cellIndex(x: Int, y: Int, z: Int) -> Int {
        return x + y * width + z * (width * height)
    }
    
    @discardableResult
    public func addSeed(_ cube: Cuboid) -> Cuboid? {
        guard cube.x < width && cube.y < height && cube.z < depth else { return nil }
        let index = cube.index(grid: self)
        if var existingCuboid = cuboids[index] {
            existingCuboid.appendVertex(cube.vertex1)
            cuboids[index] = existingCuboid
            return existingCuboid
        } else {
            cuboids[index] = cube
            seedCells.enqueue(index)
            return cube
        }
    }
    
    func findCube(at index: Int) -> Cuboid? {
        if let cuboid = cuboids[index] {
            return cuboid
        } else {
            // See which direction things are aligned at this point
            let axis = data[index] & 0x3
            assert(axis != 0)
            
            if (axis == VoxelAxis.xy.rawValue) {
                // Move left until we find a cuboid
                var offset = 1
                let maxOffset = index % self.width
                while offset < maxOffset {
                    if let cuboid = cuboids[index - offset] {
                        if cuboid.width >= offset {
                            return cuboid
                        } else {
                            return nil
                        }
                    }
                    offset += 1
                }
            } else if (axis == VoxelAxis.yz.rawValue) {
                // Move backwards until we find a cuboid
                var offset = 1
                let layerOffset = self.width * self.height
                let maxOffset = index / layerOffset
                while offset < maxOffset {
                    if let cuboid = cuboids[index - offset * layerOffset] {
                        if cuboid.depth >= offset {
                            return cuboid
                        } else {
                            return nil
                        }
                    }
                    offset += 1
                }                
            }
            return nil
        }
    }
    
    public func positionFromIndex(_ index: Int) -> (Int, Int, Int) {
        let z = Int(index / (width * height))
        let zLayerStart = z * (width * height)
        let y = Int((index - zLayerStart) / width)
        let yRowStart = zLayerStart + y * width
        let x = index - yRowStart
        return (x, y, z)
    }        
    
    public func generateMesh() -> Mesh {
        return Mesh([])
    }
}
