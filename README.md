# Dual Marching Cuboids

[![Version](https://img.shields.io/cocoapods/v/DualMarchingCuboids.svg?style=flat)](https://cocoapods.org/pods/DualMarchingCuboids)
[![License](https://img.shields.io/cocoapods/l/DualMarchingCuboids.svg?style=flat)](https://cocoapods.org/pods/DualMarchingCuboids)
[![Platform](https://img.shields.io/cocoapods/p/DualMarchingCuboids.svg?style=flat)](https://cocoapods.org/pods/DualMarchingCuboids)

A dual Marching Cubes method using cuboids, based on greedy meshing. Suitable for use with a uniform grid of data derived from multiple depth maps.

## Background

There's an endless amount of literature on converting voxel grids into polygon meshes. Academic papers have to pretend to be serious so all talk about medical imaging, but obviously more often than not it's really about the games. This project is focussed around one fairly narrow use case with some helpful limitations and some important requirements: constructing 3D buildings out of panels made from depth maps, for 3D printing, for the [Little Buildings](https://apps.apple.com/us/app/little-buildings/id1502701232?ls=1) app.

Constraints:

  * Because the voxel data is generated from depth maps, most of **the geometry is "single sided"** (i.e. all of the interesting details tend to be on one side, with very large flat 'backs' to each wall)
  * Because we populated the voxel grid ourselves, we know the maximum depth of each wall region, and importantly, for each cell we know in which direction we are likely to find the most interesting surface details and **we can assign an axis to each cell** in non-overlapping regions
  * For a mesh to be 3D printable, **it must be watertight** - i.e. any of the downsides of many existing algorithms such as self-intersecting geometry or non-manifold geometry are absolute deal breakers for us
  * Because the author is a bear of little brain, the solution needs to be **easily understood and implemented** without lots of complicated maths (or third party maths libraries which are almost as complicated as the maths itself)

### Marching Cubes

Of course the starting point for all adventures in the land of voxel meshing is the original Marching Cubes paper. You divide your space up into cells of uniform size and 'march' through them one by one. You test the corners of each cell to see whether they are 'inside' or 'outside' the mesh, and this gives you a bitmask of 8 binary values - a number between 0 and 255. This can be used as the index in a lookup table to tell you which arrangement of polygons should be output for this cell.

It sounds super simple (which is obviously part of its appeal) but there are two ingenious aspects to Marching Cubes which make it significantly more powerful than you might anticipate:

  1. The first is the clever way they just specify 15 'base' configurations from which you can derive all of the others by a series of rotations or inversions.
  2. The second, less obvious point, is that you don't just have to place the vertices in each cell at the exact centre of each edge. By use of interpolation you can construct a surprisingly sophisticated mesh - it is certainly not the case that two cells with an identical 'case number' need to result in identical polygons.

One of the main downsides of Marching Cubes is that it results in a colossal number of polygons - up to five triangles per cell, for every single cell on the surface of your mesh. Given our use case, where we have many very large, flat surfaces, this leads to vastly increased polygon counts compared with the ideal.

Another key downside of Marching Cubes is its inefficiency - if you naively traverse through every single cell in your grid then you visit a lot of cells either entirely outside or entirely inside the mesh, which contribute nothing to the final surface.

Finally, a deficit of Marching Cubes is that it is unable to represent "sharp features" - you will always end up with rounded corners. For many use cases this isn't a problem, but when adaptivity is introduced to reduce the polygon count this can become very significant.

### Octrees

Beyond the original Marching Cubes paper, many have attempted to introduce an element of 'adaptivity' - to find areas where you can reduce the sampling rate and merge polygons together. A common approach is that explained in [Octree-Based Decimation of Marching Cubes Surfaces](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.55.9425&rep=rep1&type=pdf) and is based on the concept of an 'octree' - a way of dividing 3D space in half in each of the three dimensions, resulting in 8 subspaces. Each cell can be further subdivided into eight again and again until each cell is the same of one grid cell. The algorithm then centres around merging selected octree nodes and repeating the Marching Cubes algorithm on these larger "cubes". If the distortion caused by sampling at this lower resolution is under some threshold then you proceed, otherwise the higher resolution cells are retained.

The Octree seems to be the favoured data structure in all of the literature, because it allows you to easily reason about which cells neighbour which others at varying resolutions, and for the kinds of meshes usually being considered it produces an adequate degree of adaptivity. **However, it is fairly unsatisfactory for our use case** because it works best for meshes where the sections of the mesh that can be combined are fairly evenly distributed between the eight cells. Because you can only merge whole cubes at a time, if there is very high detail in the 'front' part of the mesh and very low detail in the 'back' part of the mesh, you frequently have to choose between over-merging the front of the mesh or under-merging the back of the mesh.

The other main problem with the octree approach is the issue of so-called "cracks" that occur when a low resolution cell (which has been merged) neighbours a high resolution cell (which has not been merged). The original paper uses a form of "crack patching" that attempts to disguise the gaps by moving the higher resolution vertices to line up with the lower resolution edges. However, whilst this might *look* visually correct, it is of no value for our key requirement of water-tightness, since the crack is not actually joined up in any meaningful way. Other approaches involve filling the gap with additional triangles, but this still requires extra effort and is rather unsightly.

### Surface Tracking

The authors of Octree-Based Decimation of Marching Cubes downplay this as a mere aside, but another key concept that they introduce is the notion of "surface tracking". They make the observation that if the surface is continuous, from key "seed" cells you can just track the surface into neighbouring cells, remembering which cells you have visited previously, and very efficiently visit every non-null cell without having to examine any of the dead space around it at all. Since you know which edges the surface intersects for each Marching Cubes case, from that you can easily deduce which faces to track through. 

If you had no prior knowledge of your surface then finding those seed cells might be tricky, but since we generated our surface ourself we know exactly which cells to start from. 

### Dual Methods

To overcome several of the deficiencies of Marching Cubes, there is a whole category of solutions known as "dual" methods. Whereas Marching Cubes puts the vertices on the edges of each cube, instead the dual methods put the vertices *inside* each cell. The key observation here, which will become very important for us later on, is that you only ever need **one vertex per cell**. For the relevant groups of four cells that share a common edge you then output a quad, using the vertices from each cell.

As with Marching Cubes, the magic is in deciding *where* to position the vertex within each cell. In the most basic SurfaceNets algorithm you might just use the centre of each cell, but with fancy mathematical magic you can do significantly better than that if you know the *gradient* of the surface at each point as well (what they call "hermite data").

[Dual Contouring](https://www.cse.wustl.edu/~taoju/research/dualContour.pdf) is the most common version of this approach. The core of the idea is actually **even simpler to implement than Marching Cubes** (just look at how few lines of code [this Python sample](https://github.com/BorisTheBrave/mc-dc/blob/master/dual_contour_3d.py) requires!) but the authors of the paper do their best to obscure this with all the maths. I was scared off reading about this algorithm until right at the end of my search, whereas I wish I had started here first! There is an *excellent* [explanation of Dual Contouring](https://www.boristhebrave.com/2018/04/15/dual-contouring-tutorial/) by Boris the Brave that I recommend reading.

Just like with Marching Cubes, you can combine the dual methods with octrees to introduce some adaptivity - this is explained in the original paper, or the [Dual Marching Cubes](https://www.cs.rice.edu/~jwarren/papers/dmc.pdf) paper shows how you take each of the quads output from your Dual Contouring and apply Marching Cubes to *those*. The beauty here is that no matter how many times you merge your cells, and how large they become, in theory you still only need *one* vertex per cell. As a result, it's impossible to get cracks in these dual methods so you don't need to worry about crack patching when smaller cells meet larger cells.

Dual Contouring usually leads to much more natural looking results and can represent sharp corners. They also **correspond well to the kind of depth map data we are using** - equivalent to using one vertex per "pixel" of the depth map.

The main gotcha is that If you use the hermite data you can end up with the vertices being *outside* the cell that they belong to, which can then result in self-intersecting geometry. The fact that there's only one vertex per cell, in certain cell configurations, can also result in non-manifold geometry, where you can more than one surface sharing the same vertex but heading in different directions. Extensions of the original algorithm centre around using
more than one vertex in these situations (in Marching Cubes you might have up to four separate surface elements per cell).

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
