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
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CellIdentifier")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        textures.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
        
        cell.textLabel?.text = textures[indexPath.row]
        cell.selectionStyle = .blue
        
        return cell
    }        
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        callback?(textures[indexPath.row])
    }
}
