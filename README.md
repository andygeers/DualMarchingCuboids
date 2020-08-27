# Dual Marching Cuboids

[![Version](https://img.shields.io/cocoapods/v/DualMarchingCuboids.svg?style=flat)](https://cocoapods.org/pods/DualMarchingCuboids)
[![License](https://img.shields.io/cocoapods/l/DualMarchingCuboids.svg?style=flat)](https://cocoapods.org/pods/DualMarchingCuboids)
[![Platform](https://img.shields.io/cocoapods/p/DualMarchingCuboids.svg?style=flat)](https://cocoapods.org/pods/DualMarchingCuboids)

A dual Marching Cubes method using cuboids, based on greedy meshing. Suitable for use with a uniform grid of data derived from multiple depth maps.

## Background

There's an endless amount of literature on converting voxel grids into polygon meshes. Academic papers have to pretend to be serious so all talk about medical imaging, but obviously more often than not it's really about the games. This project is focussed around one fairly narrow use case with some helpful limitations and some important requirements: constructing 3D buildings out of panels made from depth maps, for 3D printing.

Constraints:

  * Because the voxel data is generated from depth maps, most of the geometry is "single sided" (i.e. all of the interesting details tend to be on one side, with very large flat 'backs' to each wall)
  * Because we populated the voxel grid ourselves, we know the maximum depth of each wall region
  * For a mesh to be 3D printable, it must be watertight - i.e. any of the downsides of many existing algorithms such as self-intersecting geometry or non-manifold geometry are absolute deal breakers for us

### Marching Cubes

Of course the starting point for all adventures in the land of voxel meshing is the original Marching Cubes paper. You divide your space up into cells of uniform size and 'march' through them one by one. You test the corners of each cell to see whether they are 'inside' or 'outside' the mesh, and this gives you a bitmask of 8 binary values - a number between 0 and 255. This can be used as the index in a lookup table to tell you which arrangement of polygons should be output for this cell.

It sounds super simple (which is obviously part of its appeal) but there are two ingenious aspects to Marching Cubes which make it significantly more powerful than you might anticipate:

  1. The first is the clever way they just specify 15 'base' configurations from which you can derive all of the others by a series of rotations or inversions.
  2. The second, less obvious point, is that you don't just have to place the vertices in each cell at the exact centre of each edge. By use of interpolation you can construct a surprisingly sophisticated mesh - it is certainly not the case that two cells with an identical 'case number' need to result in identical polygons.

The main downside of Marching Cubes is that it results in a colossal number of polygons - up to five triangles per cell, for every single cell on the surface of your mesh. Given our use case, where we have many very large, flat surfaces, this leads to vastly increased polygon counts compared with the ideal.

### Octrees

Beyond the original Marching Cubes paper, many have attempted to introduce an element of 'adaptivity' - to find areas where you can reduce the sampling rate and merge polygons together. A common approach is that explained in [Octree-Based Decimation of Marching Cubes Surfaces](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.55.9425&rep=rep1&type=pdf) and is based on the concept of an 'octree' - a way of dividing 3D space in half in each of the three dimensions, resulting in 8 subspaces. Each cell can be further subdivided into eight again and again until each cell is the same of one grid cell. The algorithm then centres around merging selected octree nodes and repeating the Marching Cubes algorithm on these larger "cubes". If the distortion caused by sampling at this lower resolution is under some threshold then you proceed, otherwise the higher resolution cells are retained.

The Octree seems to be the favoured data structure in all of the literature, because it allows you to easily reason about which cells neighbour which others at varying resolutions, and for the kinds of meshes usually being considered it produces an adequate degree of adaptivity. However, it is fairly unsatisfactory for our use case because it works best for meshes where the sections of the best that can be combined are fairly evenly distributed between the eight cells. Because you can only merge whole cubes at a time, if there is very high detail in the 'front' part of the mesh and very low detail in the 'back' part of the mesh, you frequently have to choose between over-merging the front of the mesh or under-merging the back of the mesh.

The other main problem with the octree approach is the issue of so-called "cracks" that occur when a low resolution cell (which has been merged) neighbours a high resolution cell (which has not been merged). The original paper uses a form of "crack patching" that attempts to disguise the gaps by moving the higher resolution vertices to line up with the lower resolution edges. However, whilst this might *look* visually correct, it is of no value for our key requirement of water-tightness, since the crack is not actually joined up in any meaningful way. Other approaches involve filling the gap with additional triangles, but this still requires extra effort and is rather unsightly.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

DualMarchingCuboids is not yet available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'DualMarchingCuboids', :git => "git@github.com:andygeers/DualMarchingCuboids.git"
```

## License

DualMarchingCuboids is available under the MIT license. See the LICENSE file for more info.
