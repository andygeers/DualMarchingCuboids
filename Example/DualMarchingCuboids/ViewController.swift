//
//  ViewController.swift
//  AdaptiveSkeletonClimbing
//
//  Created by admin@voucherpoint.uk on 07/08/2020.
//  Copyright (c) 2020 admin@voucherpoint.uk. All rights reserved.
//

import UIKit
import SceneKit
import DualMarchingCuboids
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
    @IBOutlet var wireframeSwitch : UISwitch!
    
    private var grid : VoxelGrid!
    private var seedVoxels : [SCNNode] = []
    
    private var mesher : DualMarchingCuboids!
    var polygonCount = 0
    var hasOrientedCamera = false
    var currentVoxelNode : SCNNode?
    
    var mesh : Mesh? = nil
    var wireframe : Bool = false
    var meshNode : SCNNode? = nil
    var cuboidsNode : SCNNode? = nil
    
    var textureName : String? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if (textureName == nil) {
            self.showTexturePicker()
        }
    }
    
    func showTexturePicker() {
        let texturePicker = TexturePickerViewController()
        
        texturePicker.callback = { (texture : String) in
            self.dismiss(animated: true, completion: {
                self.selectTexture(texture)
            })            
        }
        
        let nav = UINavigationController(rootViewController: texturePicker)
        
        nav.popoverPresentationController?.sourceView = self.view
        
        self.present(nav, animated: true, completion: nil)
    }
    
    func selectTexture(_ textureName: String) {
        self.textureName = textureName
        loadVoxels()
                
        initialiseScene()
        
        visualiseNextIteration()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func visualiseNextIteration() {
        var newPolygons : [Euclid.Polygon] = []
        
        mesher.generatePolygons(&newPolygons, material: UIColor.blue)
        
        //polygons.append(contentsOf: newPolygons)
        
        let mesh = Mesh(newPolygons)
        self.mesh = mesh
        
        renderMesh()
                
        NSLog("Generated mesh with %d polygon(s)", mesh.polygons.count)
    }
    
    private func renderMesh() {
        guard let scene = self.sceneView.scene else { return }
        guard let mesh = self.mesh else { return }
        
        //sceneView.pointOfView?.look(at: SCNVector3(mesh.bounds.center))
        let geom : SCNGeometry
        if (self.wireframe) {
            geom = SCNGeometry(wireframe: mesh)
        } else {
            geom = SCNGeometry(mesh, materialLookup: {
                let material = SCNMaterial()
                material.diffuse.contents = $0
                return material
            })
        }
        let node = meshNode ?? SCNNode()
        node.geometry = geom
        
        if (meshNode == nil) {
            scene.rootNode.addChildNode(node)
            self.meshNode = node
        }
        
        if (!wireframe) {
            var mesh = Mesh([])
            NSLog("Rendering %d cuboid(s)", grid.cuboids.count)
            let node2 = cuboidsNode ?? SCNNode()
            
            var childNodeIndex = 0
            for cuboid in grid.cuboids.values.map({ $0.mesh(grid: grid) }) {
                guard childNodeIndex < 0 else { break }
                
                mesh = mesh.merge(cuboid)
            
                let cuboid = SCNGeometry(mesh, materialLookup: {
                    let material = SCNMaterial()
                    material.diffuse.contents = $0
                    return material
                })
                
                let cuboidNode : SCNNode
                if (childNodeIndex < node2.childNodes.count) {
                    cuboidNode = node2.childNodes[childNodeIndex]
                    
                } else {
                    cuboidNode = SCNNode()
                    node2.addChildNode(cuboidNode)
                }
                
                cuboidNode.geometry = cuboid
                childNodeIndex += 1
            }
                        
            if (cuboidsNode == nil) {
                scene.rootNode.addChildNode(node2)
                self.cuboidsNode = node2
            }
        }
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
        guard let textureName = self.textureName else { return }
        
        // french_tiles 01_bricks
        guard let image = UIImage(named: textureName) else { return }
        
        let brickTexture : VoxelTexture?
        do {
            brickTexture = try VoxelTexture(image: image)
        } catch {
            brickTexture = nil
        }
        
        if let brickTexture = brickTexture {
            let generator = Generator(texture: brickTexture)
            
            let maxDepth = Int(ceil(generator.modelHeight + generator.baseHeight))
            width = brickTexture.width + 1
            height = brickTexture.height + 1
            depth = brickTexture.width + 1
            
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
        
        mesher = DualMarchingCuboids(grid: grid)
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

    private func exportMesh(sender: UIView) {
        guard let scene = self.sceneView.scene else { return }
        
        // Export to STL
        let outputFile = "marching_cubes.usdz"
        let documentsPath = UIApplication.cacheDirectory()
        let fileURL: URL = documentsPath.appendingPathComponent(outputFile)
                    
        if (scene.write(to: fileURL, options: [:], delegate: nil, progressHandler: nil)) {
            
            let activityVC = UIActivityViewController(activityItems: ["Share USDZ", fileURL], applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceView = self.view
            activityVC.popoverPresentationController?.sourceRect = sender.frame
            self.present(activityVC, animated: true, completion: nil)
            
        }
    }
    
    @IBAction func nextSlice(sender: UIButton) {
        exportMesh(sender: sender)        
    }
    
    @IBAction func toggleWireframe(sender: UISwitch) {
        self.wireframe = sender.isOn
        renderMesh()
    }
}

