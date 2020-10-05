//
//  AdaptiveSkeletonClimber.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 08/07/2020.
//

import Euclid

let epsilon = 1e-6

enum VoxelAxis : Int {
    case none = 0
    case xy = 1
    case yz = 2
    case multiple = 3
}

public class VoxelGrid {

    static let G_Threshold = 50.0
    
    static let occupiedFlag = 0x4
    
    public static let dataBits = 4 // Two for the axis, occupied & visited
    
    public var data : [Int]
    public let width : Int
    public let height : Int
    public let depth : Int
    
    internal var seedCells = Queue<Int>()
    public var cuboids : [Int: Cuboid] = [:]
    
    public var uglyCubes : [Int] = []
    
    public static let SCALE_FACTOR = 500.0
    
    public init(width : Int, height : Int, depth : Int) {
        self.width = width
        self.height = height
        self.depth = depth
        self.data = [Int](repeating: 0, count: width * height * depth)
    }
    
    public convenience init(bounds: Bounds) {
        self.init(width: Int(bounds.size.x * VoxelGrid.SCALE_FACTOR) + 2,
                  height: Int(bounds.size.y * VoxelGrid.SCALE_FACTOR) + 2,
                  depth: Int(bounds.size.z * VoxelGrid.SCALE_FACTOR) + 2)
    }
    
    public extension Plane {
        var pointOnPlane : Vector {
            if (self.normal.z != 0.0) {
                let x = 0.0
                let y = 0.0
                let z = self.w / self.normal.z
                return Vector(x, y, z)
            } else if (self.normal.y != 0.0) {
                let x = 0.0
                let y = self.w / self.normal.y
                let z = 0.0
                return Vector(x, y, z)
            } else {
                let x = self.w / self.normal.x
                let y = 0.0
                let z = 0.0
                return Vector(x, y, z)
            }
        }
    }
    
    public func slice(plane: Plane, bounds: Bounds) -> Slice? {
        // See what kind of slice we want
        if (abs(plane.normal.y) < epsilon) {
            if (abs(plane.normal.x) < epsilon) {
                if (plane.normal.z > 0) {
                    let z = plane.w / plane.normal.z
                    
                    return XYSlice(grid: self, z: Int(z * VoxelGrid.SCALE_FACTOR) + 1)
                } else {
                    // TODO: Reverse XY slice
                    return nil
                }
            } else if (abs(plane.normal.z) < epsilon) {
                if (plane.normal.x > 0) {
                    let x = plane.w / plane.normal.x
                    
                    return YZSlice(grid: self, x: Int(x * VoxelGrid.SCALE_FACTOR) + 1)
                } else {
                    // TODO: Revert YZ slice
                    return nil
                }
            } else {
                return nil
            }
        } else {
            // For now we only support 'vertical' panels
            return nil
        }
    }
    
    public func cellIndex(x: Int, y: Int, z: Int) -> Int {
        return x + y * width + z * (width * height)
    }
    
    @discardableResult
    public func addSeed(_ cube: Cuboid) -> Cuboid? {
        guard cube.x < width && cube.y < height && cube.z < depth else { return nil }
        let index = cube.index(grid: self)
        if var existingCuboid = findCuboid(at: index) {
            existingCuboid.appendVertex(cube.vertex1)
            existingCuboid.axis = .multiple
            //existingCuboid.surfaceNormal = Vector.zero
            let cuboidIndex = existingCuboid.index(grid: self)
            cuboids[cuboidIndex] = existingCuboid
            return existingCuboid
        } else {
            cuboids[index] = cube
            seedCells.enqueue(index)
            return cube
        }
    }
    
    func findCuboid(at index: Int) -> Cuboid? {
        if let cuboid = cuboids[index] {
            return cuboid
        } else {
            guard index >= 0 && index < data.count else { return nil }
            
            // See which direction things are aligned at this point
            let gridData = data[index]
            let cellIndex = gridData >> VoxelGrid.dataBits
            guard cellIndex > 0 else { return nil }
            
            if let cuboid = cuboids[cellIndex] {
                assert(cuboid.containsIndex(index, grid: self))
                return cuboid
            } else {
                return nil
            }
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
