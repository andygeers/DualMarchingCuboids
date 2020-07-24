//
//  ViewController.swift
//  AdaptiveSkeletonClimbing
//
//  Created by admin@voucherpoint.uk on 07/08/2020.
//  Copyright (c) 2020 admin@voucherpoint.uk. All rights reserved.
//

import UIKit
import SceneKit
import AdaptiveSkeletonClimbing

let SCALE_FACTOR : CGFloat = 0.1

private func rnd() -> Float {
    return 0.01 * Float(SCALE_FACTOR) * ((Float(arc4random()) / Float(RAND_MAX)) - 0.5)
}

class ViewController: UIViewController {

    var gridData : [CUnsignedChar] = []
    var width = 0
    var height = 0
    var depth = 0
    
    let threshold : CUnsignedChar = 50
    
    @IBOutlet var sceneView : SCNView!
    
    private var contourTracer : ContourTracer!
    private var currentSliceIndex = 0
    private var currentSlice : Slice? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        loadVoxels()
        
        contourTracer = ContourTracer(G_data1: gridData, G_DataWidth: width, G_DataHeight: height, G_DataDepth: depth)
        
        //generateMesh()
        visualiseNextSlice()
        
        self.sceneView.allowsCameraControl = true
        self.sceneView.showsStatistics = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func visualiseNextSlice() {
        if currentSlice != nil {
            currentSliceIndex += 1
        }
        guard let currentSlice = Slice(contourTracer: contourTracer, z: currentSliceIndex, previousSlice: currentSlice) else { return }
        
        self.currentSlice = currentSlice
        
        let scene = SCNScene()
        
        let voxels = SCNNode()
        
        let particle = voxelGeometry()
        
        var k = 0
        for y in 0 ..< height {
            for x in 0 ..< width {
                if currentSlice.depthCounts[k] != 0 {
                    let depthColour = colourForDepth(currentSlice.depthCounts[k])
                    let voxelNode = generateVoxel(x: x, y: y, z: currentSliceIndex, particle: particle, colour: depthColour)
                    
                    voxels.addChildNode(voxelNode)
                }
                
                k += 1
            }
        }
        
        NSLog("Found %d voxel(s)", voxels.childNodes.count)
        
        scene.rootNode.addChildNode(voxels)
        
        addCamera(to: scene)
        
        self.sceneView.scene = scene
    }
    
    private func colourForDepth(_ depth : Int) -> UIColor {
        let saturation = 1.0 - CGFloat(depth) / CGFloat(contourTracer.G_DataDepth)
        let hue : CGFloat = depth > 0 ? 0.5 : 0.0
        return UIColor(hue: hue, saturation: saturation, brightness: 1.0, alpha: 1.0)
    }
    
    private func loadVoxels() {
        guard let image = UIImage(named: "01_bricks") else { return }
        do {
            (gridData, width, height, depth) = try Generator().processImage(image: image)
        } catch {
            return
        }
    }
    
    private func generateMesh() {
        NSLog("Generating mesh")
        
        let mesh = contourTracer.climb()
        
        NSLog("Generated mesh with %d polygon(s)", mesh.polygons.count)
        
        let scene = SCNScene()
        
        let geometry = SCNGeometry(mesh, materialLookup: {
            let material = SCNMaterial()
            material.diffuse.contents = $0
            return material
        })
        let node = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(node)
        
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.0, 50.0, 50.0)
        cameraNode.look(at: SCNVector3(0.0, 0.0, 0.0))
        
        self.sceneView.scene = scene
        
        self.sceneView.allowsCameraControl = true
        self.sceneView.showsStatistics = true
    }
    
    private func generateVoxel(x : Int, y : Int, z : Int, particle : SCNGeometry, colour: UIColor = .red) -> SCNNode {
        let voxelNode = SCNNode(geometry: (particle.copy() as! SCNGeometry))
        voxelNode.position = SCNVector3Make(Float(x) + rnd(), Float(y), Float(z) + rnd())
        let material = SCNMaterial()
        material.diffuse.contents = colour
        voxelNode.geometry!.firstMaterial = material
        return voxelNode
    }
    
    private func voxelGeometry() -> SCNGeometry {
        return SCNBox(width: 2.0 * SCALE_FACTOR, height: 2.0 * SCALE_FACTOR, length: 2.0 * SCALE_FACTOR, chamferRadius: 0.0)
    }
    
    private func addCamera(to scene : SCNScene) {
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.0, 50.0, 50.0)
        cameraNode.look(at: SCNVector3(0.0, 0.0, 0.0))
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func visualiseVoxels() {
        
        let scene = SCNScene()
        
        let voxels = SCNNode()
        
        let particle = voxelGeometry()
        
        var k = 0
        for z in 0 ..< depth {
            for y in 0 ..< height {
                for x in 0 ..< width {
                    if gridData[k] >= threshold {
                        let voxelNode = generateVoxel(x: x, y: y, z: z, particle: particle)
                        
                        voxels.addChildNode(voxelNode)
                    }
                    
                    k += 1
                }
            }
        }
        
        NSLog("Found %d voxel(s)", voxels.childNodes.count)
        
        scene.rootNode.addChildNode(voxels)
        
        addCamera(to: scene)
        
        self.sceneView.scene = scene
    }

}

