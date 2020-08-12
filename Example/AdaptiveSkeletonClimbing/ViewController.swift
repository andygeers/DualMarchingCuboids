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

    var gridData : [Int] = []
    var polygons : [Euclid.Polygon] = []
    var width = 0
    var height = 0
    var depth = 0
    
    let threshold : CUnsignedChar = 50
    
    @IBOutlet var sceneView : SCNView!
    
    private var grid : VoxelGrid!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        loadVoxels()
                
        initialiseScene()
        
        //generateMesh()
        visualiseNextSlice()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func visualiseNextSlice() {
        guard let scene = self.sceneView.scene else { return }
        
        var polygonCount = 0
        
        for currentSlice in grid {
        
            var newPolygons : [Euclid.Polygon] = []
            currentSlice.generatePolygons(&newPolygons, material: colourForSlice(currentSlice.layerDepth))
            polygons.append(contentsOf: newPolygons)
            
            let mesh = Mesh(newPolygons)
            polygonCount += mesh.polygons.count
            
            sceneView.pointOfView?.look(at: SCNVector3(mesh.bounds.center))
            
            let geom = SCNGeometry(mesh, materialLookup: {
                let material = SCNMaterial()
                material.diffuse.contents = $0
                return material
            })
            let node = SCNNode(geometry: geom)
            scene.rootNode.addChildNode(node)
            
            let voxels = SCNNode()
            
            let particle = voxelGeometry()
            
            for (x, y, z, _, _, k) in currentSlice {
                let cellData = grid.data[k] >> 2
                if cellData != 0 && grid.data[k] & 0x3 == 1 && (x < 25 || y < 25 || z < 25) && false {
                    let depthColour = colourForDepth(cellData)
                    let voxelNode = generateVoxel(x: x, y: y, z: z, particle: particle, colour: depthColour)
                    
                    voxels.addChildNode(voxelNode)
                }
            }
            
            NSLog("Found %d voxel(s)", voxels.childNodes.count)
            
            scene.rootNode.addChildNode(voxels)
        }
        
        NSLog("Generated %d polygon(s)", polygonCount)
    }
    
    private func colourForSlice(_ z : Int) -> UIColor {
        let saturation = CGFloat(z + 1) / CGFloat(grid.depth + 1)
        let hue : CGFloat = 0.7 + saturation * 0.2
        return UIColor(hue: hue, saturation: saturation, brightness: 1.0, alpha: 0.6)
    }
    
    private func colourForDepth(_ depth : Int) -> UIColor {
        let saturation = CGFloat(abs(depth) + 1) / CGFloat(grid.depth + 1)
        let hue : CGFloat = (depth > 0 ? 0.5 : 0.0) + saturation * 0.2
        return UIColor(hue: hue, saturation: saturation, brightness: 1.0, alpha: 1.0)
    }
    
    private func loadVoxels() {
        guard let image = UIImage(named: "01_bricks") else { return }
        
        let brickTexture : VoxelTexture?
        do {
            brickTexture = try VoxelTexture(image: image)
        } catch {
            brickTexture = nil
        }
        
        if let brickTexture = brickTexture {
            let generator = Generator(texture: brickTexture)
            
            let maxDepth = Int(ceil(generator.modelHeight + generator.baseHeight))
            width = brickTexture.width
            height = brickTexture.height
            depth = brickTexture.width
            
            grid = VoxelGrid(width: width, height: height, depth: depth)
            
            guard let xySlice = XYSlice(grid: grid, z: grid.depth - maxDepth - 1) else { return }
            generator.generateSurface(on: xySlice)
            
            guard let yzSlice = YZSlice(grid: grid, x: grid.width - maxDepth - 1) else { return }
            generator.generateSurface(on: yzSlice)                        
            
        } else {
            width = 10
            height = 10
            depth = 10
            
            grid = VoxelGrid(width: width, height: height, depth: depth)
        }
        
    }
    
    private func generateMesh() {
        NSLog("Generating mesh")
        
        let mesh = grid.generateMesh()
        
        NSLog("Generated mesh with %d polygon(s)", mesh.polygons.count)
        
        let scene = SCNScene()
        
        let geometry = SCNGeometry(mesh, materialLookup: {
            let material = SCNMaterial()
            material.diffuse.contents = $0
            return material
        })
        let node = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(node)
        
//        let cameraNode = SCNNode()
//        let camera = SCNCamera()
//        cameraNode.camera = camera
//        scene.rootNode.addChildNode(cameraNode)
//        cameraNode.position = SCNVector3(150.0, 0.0, 150.0)
//        cameraNode.look(at: SCNVector3(0.0, 0.0, 0.0))
        
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
        camera.zFar = 200.0
        cameraNode.position = SCNVector3(CGFloat(width) * 0.5, CGFloat(height) / 2.0, CGFloat(depth) * 1.5)
        cameraNode.look(at: SCNVector3(CGFloat(width) / 2.0, CGFloat(height) / 2.0, 0.0))
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func addLighting(to scene : SCNScene) {
        let height : Float = 1.0
        
        let spotLight = SCNLight()
        spotLight.type = .directional
        spotLight.intensity = 600
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
        addLighting(to: scene)
        
        self.sceneView.scene = scene
        
        self.sceneView.allowsCameraControl = true
        self.sceneView.showsStatistics = true
    }

    @IBAction func nextSlice() {
        visualiseNextSlice()
    }
}

