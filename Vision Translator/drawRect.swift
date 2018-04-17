//
//  drawRect.swift
//  Vision Translator
//
//  Created by James Galante on 4/12/18.
//  Copyright © 2018 devcrew. All rights reserved.
//

import Foundation

class DrawRect: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func draw(_ rect: CGRect) {
        let h = rect.height
        let w = rect.width
        let color: UIColor = UIColor.yellow
        
        let drect = CGRect(x: (w * 0.25),y: (h * 0.25),width: (w * 0.5),height: (h * 0.5))
        let bpath:UIBezierPath = UIBezierPath(rect: drect)
        
        color.set()
        bpath.stroke()
        
        print("it ran")
        NSLog("drawRect has updated the view")
        
    }
    
}
