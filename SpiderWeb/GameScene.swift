//
//  GameScene.swift
//  SpiderWeb
//
//  Created by Stephen Brennan on 7/7/16.
//  Copyright (c) 2016 Stephen Brennan. All rights reserved.
//

import SpriteKit

func computeMagnitude(p1:CGPoint, p2: CGPoint) -> CGFloat{
    let dx = pow(p1.x - p2.x, 2)
    let dy = pow(p1.y - p2.y, 2)
    
    return pow(dx + dy, 0.5)
}

class ScbLine : SKShapeNode {
    enum States {
        case Create
        case DragStart
        case DragEnd
        case DragMiddle
    }
    var state = States.Create
    
    let start : CGPoint
    var end : CGPoint?
    var dragStart : CGPoint?
    
    init(start : CGPoint, scene: SKScene) {
        self.start = start
        super.init()
        let path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, start.x, start.y)
        self.path = path
        self.lineWidth = 5
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func computeMidPoint() -> CGPoint {
        let pts = getPoints()
        let p1 = pts.p1
        let p2 = pts.p2
        
        let dx2 = abs(p1.x - p2.x) / 2.0
        let dy2 = abs(p1.y - p2.y) / 2.0
        let mx = min([p1.x, p2.x]) + dx2
        let my = min([p1.y, p2.y]) + dy2
        
        return CGPoint(x: mx, y: my)
        
    
    }
    func min(arr : [CGFloat]) -> CGFloat {
        var ret = CGFloat.max
        
        for f in arr {
            if f < ret {
                ret = f
            }
        }
        return ret
    }
    func touchBegin(location : CGPoint) {
        let mp = computeMidPoint()
        let pts = getPoints()
        let p1m = computeMagnitude(location, p2: pts.p1)
        let p2m = computeMagnitude(location, p2: pts.p2)
        let mpm = computeMagnitude(location, p2: mp)
        
        let m = min([p1m, p2m, mpm])
        
        if m == p1m {
            state = .DragStart
        } else if m == p2m {
            state = .DragEnd
        } else {
            state = .DragMiddle
            dragStart = location
        }
        start
    }
    
    func move(point : CGPoint) {
        switch (state) {
        case .Create:
            let path = CGPathCreateMutable()
            CGPathMoveToPoint(path, nil, start.x, start.y)
            CGPathAddLineToPoint(path, nil, point.x, point.y)
            self.path = path
            end = point
        case .DragMiddle:
            let dx = point.x - dragStart!.x
            let dy = point.y - dragStart!.y
            var xlat = CGAffineTransformMakeTranslation(dx, dy)
            let mp = CGPathCreateCopyByTransformingPath(self.path, &xlat)
            self.path = mp
            dragStart = point
        case .DragStart, .DragEnd:
            let pts = getPoints()
            let sp = state == .DragStart ? point : pts.p1
            let ep = state == .DragEnd ? point : pts.p2
            let path = CGPathCreateMutable()
            CGPathMoveToPoint(path, nil, sp.x, sp.y)
            CGPathAddLineToPoint(path, nil, ep.x, ep.y)
            self.path = path
        }
    }
    
    func checkNear(p1 : CGPoint, p2: CGPoint) -> Bool {
        let mag = computeMagnitude(p1, p2: p2)
        return mag < 20
    }
    
    func near(point : CGPoint) -> CGPoint? {
        var toProcess = [ start ]
        if let e = end {
            toProcess.append(e)
        }
        for p in toProcess {
            if checkNear(p, p2: point) {
                return p
            }
        }
        return nil
    }
    func getPoints() -> (p1: CGPoint, p2: CGPoint) {
        var points = [CGPoint]()
        
        withUnsafeMutablePointer(&points) { pPoints in
            CGPathApply(path, pPoints, {
                ptr, ele in
                let pe : CGPathElement = ele.memory
                if let pt = pe.points.memory as? CGPoint {
                    let arr = UnsafeMutablePointer<[CGPoint]>(ptr)
                    arr.memory.append(pt)
                }
            })
        }
        
        return (points[0], points[1])
        
    }
    func intersectsPoint(p : CGPoint) -> Bool {
        let ps = getPoints()
        let p1 = ps.p1
        let p2 = ps.p2
        
        let dx1 = p1.x - p2.x
        let dy1 = p1.y - p2.y
        let slope1 = dx1 / dy1
        
        let dx2 = p1.x - p.x
        let dy2 = p1.y - p.y
        let slope2 = dx2 / dy2
        let ds = abs(slope2 - slope1)
        
        // print("slope1 \(slope1), slope2 \(slope2), ds: \(ds)")
        
        return ds < 0.1;
    }
    func computeNear() -> Bool {
        return state != .DragMiddle
    }
}

class GameScene: SKScene {
    var touchMap = [ UITouch : ScbLine ]()
    override func didMoveToView(view: SKView) {
        /* Setup your scene here */
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for t in touches {
            var location = t.locationInNode(self)
            var found : ScbLine?
            for hit in self.nodesAtPoint(location) {
                if let n = hit as? ScbLine {
                    if n.intersectsPoint(location) {
                        found = n
                        break
                    }
                }
            }
            if let n = found {
                touchMap[t] = n
                n.touchBegin(location)
            } else {
                if let p = near(location) {
                    location = p
                }
                let tad = ScbLine(start: location, scene: self)
                touchMap[t] = tad
                self.addChild(tad)
            }
            
        }
    }
    
    func near(inPoint : CGPoint) -> CGPoint? {
        for c in self.children {
            if let l = c as? ScbLine {
                if let p = l.near(inPoint) {
                    return p
                }
            }
        }
        return nil
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for t in touches {
            let location = t.locationInNode(self)
            if let tad = touchMap[t] {
                tad.move(location)
            }
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for t in touches {
            var location = t.locationInNode(self)
            if let tad = touchMap[t] {
                touchMap.removeValueForKey(t)
                if tad.computeNear() {
                    
                    if let p = near(location) {
                        location = p
                    }
                }
                tad.move(location)
                
            }
        }
    }
    
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
    }
}
