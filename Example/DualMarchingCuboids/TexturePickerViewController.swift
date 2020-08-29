//
//  TexturePicker.swift
//  DualMarchingCuboids_Example
//
//  Created by Andy Geers on 29/08/2020.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

class TexturePickerViewController : UITableViewController {
    let textures = ["01_bricks", "french_tiles", "02_wood", "03_tiles", "corrugated_iron"]
    var callback : ((String) -> Void)? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Select texture"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        textures.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier")
        if (cell == nil) {
            cell = UITableViewCell(style: .default, reuseIdentifier: "CellIdentifier")
        }
        
        cell!.textLabel?.text = textures[indexPath.row]
        
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        callback?(textures[indexPath.row])
    }
}
