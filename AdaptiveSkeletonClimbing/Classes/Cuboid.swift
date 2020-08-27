//
//  Cuboid.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 27/08/2020.
//

import Foundation
import Euclid

struct Cuboid {
//    let x : Int
//    let y : Int
//    let z : Int
    let index : Int // Can derive x, y, z from this
    
    let width : Int
    let height : Int
    let depth : Int
    
    // There can be up to four discreet surfaces
    // in the most complex Marching Cubes case
    let vertex1 : Vector
    let vertex2 : Vector
    let vertex3 : Vector
    let vertex4 : Vector
    
    // There may of course be a lot of nodes along each edge, for large cuboids,
    // but we can find all of the others by traversing from the first one on that edge
    let upNodeIndex : Int
    let rightNodeIndex : Int
    let downNodeIndex : Int
    let leftNodeIndex : Int
    let forwardsNodeIndex : Int
    let backwardsNodeIndex : Int
}
