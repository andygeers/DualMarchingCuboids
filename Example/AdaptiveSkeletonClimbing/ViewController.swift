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
import Euclid

let SCALE_FACTOR : CGFloat = 0.1

private func rnd() -> Float {
    return 0.01 * Float(SCALE_FACTOR) * ((Float(arc4random()) / Float(RAND_MAX)) - 0.5)
}

class ViewController: UIViewController {

    var gridData : [CUnsignedChar] = []
    var polygons : [Euclid.Polygon] = []
    var width = 0
    var height = 0
    var depth = 0
    
    let threshold : CUnsignedChar = 50
    
    @IBOutlet var sceneView : SCNView!
    
    private var contourTracer : ContourTracer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        loadVoxels()
        
        contourTracer = ContourTracer(G_data1: gridData, G_DataWidth: width, G_DataHeight: height, G_DataDepth: depth)
        
        initialiseScene()
        
        generateMesh()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func colourForSlice(_ z : Int) -> UIColor {
        let saturation = CGFloat(z + 1) / CGFloat(contourTracer.G_DataDepth + 1)
        let hue : CGFloat = 0.7 + saturation * 0.2
        return UIColor(hue: hue, saturation: saturation, brightness: 1.0, alpha: 0.6)
    }
    
    private func colourForDepth(_ depth : Int) -> UIColor {
        let saturation = CGFloat(abs(depth) + 1) / CGFloat(contourTracer.G_DataDepth + 1)
        let hue : CGFloat = (depth > 0 ? 0.5 : 0.0) + saturation * 0.2
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
        
        let net = SurfaceNet(contourTracer: contourTracer)
        let mesh = net.generate()
        
        NSLog("Generated mesh with %d polygon(s)", mesh.polygons.count)
        
        let geometry = SCNGeometry(mesh, materialLookup: {
            let material = SCNMaterial()
            material.diffuse.contents = $0
            material.isDoubleSided = true
            return material
        })
        let node = SCNNode(geometry: geometry)
        sceneView.scene!.rootNode.addChildNode(node)
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
        cameraNode.position = SCNVector3(CGFloat(width) / 2.0, CGFloat(height) / 2.0, 50.0)
        cameraNode.look(at: SCNVector3(CGFloat(width) / 2.0, CGFloat(height) / 2.0, 0.0))
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func addLights(to scene : SCNScene) {
        let height : Float = 3
        let intensity: CGFloat = 600
        
        let spotLight = SCNLight()
        spotLight.type = .directional
        spotLight.intensity = intensity
        spotLight.color = UIColor.white
        let spotNode = SCNNode()
        spotNode.light = spotLight
        spotNode.position = SCNVector3(x: 3, y: height, z: 3)
        spotNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(spotNode)
        
        let spotLight2 = SCNLight()
        spotLight2.type = .directional
        spotLight2.intensity = 600
        spotLight2.color = UIColor.white
        let spotNode2 = SCNNode()
        spotNode2.light = spotLight
        scene.rootNode.addChildNode(spotNode2)
        spotNode2.position = SCNVector3(x: -3, y: height, z: -3)
        spotNode2.look(at: SCNVector3(x: 0, y: 0, z: 0))
        
        //spotNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 100
        ambientLight.color = UIColor.white
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
    }
    
    private func initialiseScene() {
        let scene = SCNScene()
        
        self.sceneView.autoenablesDefaultLighting = false
        
        addCamera(to: scene)
        addLights(to: scene)
        
        self.sceneView.scene = scene
        
        self.sceneView.allowsCameraControl = true
        self.sceneView.showsStatistics = true
    }
    
    private func visualiseVoxels() {
        
        guard let scene = self.sceneView.scene else { return }
        
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
    }

    @IBAction func nextSlice() {
        
    }
}

