//
//  ViewController.swift
//  AdaptiveSkeletonClimbing
//
//  Created by admin@voucherpoint.uk on 07/08/2020.
//  Copyright (c) 2020 admin@voucherpoint.uk. All rights reserved.
//

import UIKit
import SceneKit

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        loadVoxels()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func loadVoxels() {
        guard let image = UIImage(named: "01_bricks") else { return }
        do {
            (gridData, width, height, depth) = try Generator().processImage(image: image)
        } catch {
            return
        }
        
        let scene = SCNScene()
        
        let voxels = SCNNode()
        
        let particle = SCNBox(width: 2.0 * SCALE_FACTOR, height: 2.0 * SCALE_FACTOR, length: 2.0 * SCALE_FACTOR, chamferRadius: 0.0)
        
        var k = 0
        for z in 0 ..< depth {
            for y in 0 ..< height {                
                for x in 0 ..< width {
                    //let index = x + y * width + z * (width * height)
                    if gridData[k] >= threshold {
                        let voxelNode = SCNNode(geometry: (particle.copy() as! SCNGeometry))
                        voxelNode.position = SCNVector3Make(Float(x) + rnd(), Float(y), Float(z) + rnd())
                        let material = SCNMaterial()
                        material.diffuse.contents = UIColor.red
                        voxelNode.geometry!.firstMaterial = material
                        
                        voxels.addChildNode(voxelNode)
                    }
                    
                    k += 1
                }
            }
        }
        
        NSLog("Found %d voxel(s)", voxels.childNodes.count)
        
        scene.rootNode.addChildNode(voxels)
        
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.0, 50.0, 50.0)
        cameraNode.look(at: SCNVector3(0.0, 0.0, 0.0))
        
        self.sceneView.scene = scene
        
        self.sceneView.allowsCameraControl = true
        self.sceneView.showsStatistics = true
        
    }

}

