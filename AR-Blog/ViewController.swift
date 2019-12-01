//
//  ViewController.swift
//  AR-Blog
//
//  Created by Daniel Radshun on 26/11/2019.
//  Copyright © 2019 Daniel Radshun. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, ARCoachingOverlayViewDelegate, SCNNodeRendererDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var sceneNode = SCNNode()
    var isHorizontalPlaneSet = false
    var isVerticalPlaneSet = false
    var nodesBoxes:[SCNNode] = []
    var faceNode:SCNNode?
    var bodyNode:SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        loadLogoScene()
        
        let longTapGesture = UILongPressGestureRecognizer(target: self, action: #selector(ViewController.handleLongTap(gestureRecognize:)))
        sceneView.addGestureRecognizer(longTapGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(gestureRecognize:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Create a new scene
//        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
//        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setUpCoachingOverlay()
                
        configurateWorldTracking()
        
//        configurateFaceTracking()
        
//        configurateBodyTracking()
    }
    
    fileprivate func configurateBodyTracking(){
        guard ARBodyTrackingConfiguration.isSupported else { return }
        let configuration = ARBodyTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.automaticSkeletonScaleEstimationEnabled = true
        configuration.frameSemantics.insert(.bodyDetection)
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    fileprivate func configurateFaceTracking(){
        // Create a face configuration session
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.maximumNumberOfTrackedFaces = 10
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
        
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
            
        // Pause the view's session
        sceneView.session.pause()
    }
    
    fileprivate func setUpCoachingOverlay() {
        let coachingOverlay = ARCoachingOverlayView()
        
        coachingOverlay.session = sceneView.session
        coachingOverlay.delegate = self
        
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(coachingOverlay)
        
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.goal = .horizontalPlane
    }
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
    }
    
    @objc func handleLongTap(gestureRecognize: UILongPressGestureRecognizer) {
        
        if(gestureRecognize.view == self.sceneView){
            let viewTouchLocation = gestureRecognize.location(in: sceneView)
            guard let result = sceneView.hitTest(viewTouchLocation, options: nil).first else {
                return
            }
            for node in nodesBoxes{
                if node == result.node{
                    node.removeAllAnimations()
                    addAnimation(node: node)
//                    node.removeFromParentNode()
                }
            }
        }
    }
    
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Create anchor using the camera's current position
        if let currentFrame = sceneView.session.currentFrame {
            
            // Create a transform with a translation of 2 meters in front of the camera
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -2
            print(translation)
            let transform = simd_mul(currentFrame.camera.transform, translation)
            
            // Add a new anchor to the session
            let anchor = ARAnchor(name: "tap", transform: transform)
            sceneView.session.add(anchor: anchor)
        }
    }
    
    private func loadLogoScene() {
        guard let scene = SCNScene(named: "art.scnassets/msapps.scn") else {
            print("Could not load scene!")
            return
        }

        let childNodes = scene.rootNode.childNodes
        for childNode in childNodes {
            sceneNode.addChildNode(childNode)
        }
    }
    
    private func loadBoxScene() -> [SCNNode]? {
        guard let scene = SCNScene(named: "art.scnassets/box.scn") else {
            print("Could not load scene!")
            return nil
        }
        let childNodes = scene.rootNode.childNodes
        return childNodes
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let planeAnchor = anchor as? ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane {
            
                plane.width = CGFloat(planeAnchor.extent.x)
                plane.height = CGFloat(planeAnchor.extent.z)
                planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        }
        
        //face recognition
        if let faceAnchor = anchor as? ARFaceAnchor,
            let faceNode = self.faceNode,
            let faceGeometry = faceNode.geometry as? ARSCNFaceGeometry{

            let material = faceGeometry.firstMaterial!
            
            if faceAnchor.blendShapes[.jawOpen]!.doubleValue > 0.6{
                material.diffuse.contents = #imageLiteral(resourceName: "smile")
            }
            else{
                 material.diffuse.contents = #imageLiteral(resourceName: "ms-c-logo")
            }
            
            faceGeometry.update(from: faceAnchor.geometry)
        }
//        else if let bodyAnchor = anchor as? ARBodyAnchor{
//
//            print("PERSON DETECTED")
//            let position = bodyAnchor.skeleton.jointLocalTransforms.first?.position()
//            if !isVerticalPlaneSet{
//                isVerticalPlaneSet = true
//                bodyNode?.position = position!
//            }
//        }
        
    }
    

    //ARSCNViewDelegate

    /*
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
     */
}

//MARK: World Tracking Configuration
extension ViewController{
    
    fileprivate func configurateWorldTracking() {
        // Create a world configuration session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.frameSemantics.insert(.personSegmentationWithDepth)
//        configuration.maximumNumberOfTrackedImages = 10
        if #available(iOS 12.0, *) {
            configuration.environmentTexturing = .automatic
        }
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let planeAnchor = anchor as? ARPlaneAnchor {
            let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
            plane.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.75)

            let planeNode = SCNNode(geometry: plane)

            planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.x, planeAnchor.center.z)
            //rotate the plane anchor 90 degrees
            planeNode.eulerAngles.x = -.pi / 2

            node.addChildNode(planeNode)
        }
        
        if let planeAnchor = anchor as? ARPlaneAnchor{
            if planeAnchor.alignment == .horizontal,
                !isHorizontalPlaneSet{
                isHorizontalPlaneSet = true
                sceneNode.scale = SCNVector3(0.1, 0.1, 0.1)
                sceneNode.position = SCNVector3Zero
                node.addChildNode(sceneNode)
            }
            else if planeAnchor.alignment == .vertical,
                !isVerticalPlaneSet{
                isVerticalPlaneSet = true
                let plane = SCNPlane(width: 0.4, height: 0.25)
                let material = SCNMaterial()
                material.diffuse.contents = UIImage(named: "ms-c-logo")
                plane.materials = [material]

                let planeNode = SCNNode(geometry: plane)

                planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.x, planeAnchor.center.z)
                //rotate the plane anchor 90 degrees
                planeNode.eulerAngles.x = -.pi / 2

                node.addChildNode(planeNode)
            }
        }
        //check if the anchor made by tap
        else if anchor.name == "tap",
            let nodes = loadBoxScene(){
            sceneNode.scale = SCNVector3(0.1, 0.1, 0.1)
            for childNode in nodes {
                let position = SCNVector3(SCNVector3Zero.x, SCNVector3Zero.y, anchor.transform.position().z)
                childNode.position = position
                nodesBoxes.append(childNode)
                node.addChildNode(childNode)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if let camera = sceneView.session.currentFrame?.camera {
            let transform = camera.transform
            let position = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            updateCameraPosition(position)
        }
    }
    
    func updateCameraPosition(_ cameraPosition: SCNVector3) {
        
        for node in nodesBoxes{
            if cameraPosition.distance(to: node.position) < 2{
                
                changeNodeColorOf(node, to: .blue)
            }
            else{
                changeNodeColorOf(node, to: .red)
            }
        }
    }
    
    func changeNodeColorOf(_ node:SCNNode,to color:UIColor){
        // Un-share the geometry by copying
        node.geometry = node.geometry?.copy() as? SCNGeometry
        // Un-share the material, too
        node.geometry?.firstMaterial = node.geometry?.firstMaterial!.copy() as? SCNMaterial
        // Now, we can change node's material without changing parent and other childs:
        node.geometry?.firstMaterial?.diffuse.contents = color
    }
    
    func addAnimation(node: SCNNode) {
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat(Float.pi), z: 0, duration: 5.0)
//        let scaleUp = SCNAction.scale(by: 1.1, duration: 2)
//        let scaleDown = SCNAction.scale(by: 1/1.1, duration: 2)
//        let scaleSequence = SCNAction.sequence([scaleUp, scaleDown])
//        let rotateAndScale = SCNAction.group([rotate, scaleSequence])
        let repeatForever = SCNAction.repeatForever(rotate)
        node.runAction(repeatForever)
    }
}

extension matrix_float4x4 {
    func position() -> SCNVector3 {
        return SCNVector3Make(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension SCNVector3 {
    public func distance(to vector:SCNVector3) -> Float {
        let xd = vector.x - self.x
        let yd = vector.y - self.y
        let zd = vector.z - self.z
        
        //calculate the distance
        let distance = Float(sqrt(xd * xd + yd * yd + zd * zd))
        
        if (distance < 0){
            return (distance * -1)
        } else {
            return (distance)
        }
    }
}

//MARK: Face and Body Tracking Configuration
extension ViewController{
    
    //COMMENT IT TO MAKE THE WORLD TRACKING WORK PROPERLY
    /*
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // This class adds AR content only for face anchors.
        if anchor is ARFaceAnchor{
        
            guard let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!) else {return nil}
            let material = faceGeometry.firstMaterial!

            material.diffuse.contents = #imageLiteral(resourceName: "ms-c-logo")
            material.lightingModel = .physicallyBased
            
            let contentNode = SCNNode(geometry: faceGeometry)
            faceNode = contentNode
            return contentNode
        }
        else if let bodyAnchor = anchor as? ARBodyAnchor{

            print("PERSON DETECTED")
            let nodes = loadBoxScene()
            sceneNode.scale = SCNVector3(0.1, 0.1, 0.1)
            for childNode in nodes! {
                let position = bodyAnchor.skeleton.jointLocalTransforms.first?.position()
                childNode.position = position!
                bodyNode = childNode
                return childNode
            }
        }
        
        return nil
    }
    

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let person = frame.detectedBody
        let landmarks = person?.skeleton.jointLandmarks
        //draw with the landmarks
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
                  
            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
            let position = bodyPosition + hipToFootOffset
            
            print("BODY DETECTED")
        }
     }
    */
    var hipToFootOffset: Float {
        // Get an index for a foot.
        let footIndex = ARSkeletonDefinition.defaultBody3D.index(for: .leftFoot)
        // Get the foot's world-space offset from the hip.
        let footTransform = ARSkeletonDefinition.defaultBody3D.neutralBodySkeleton3D!.jointModelTransforms[footIndex]
        // Return the height by getting just the y-value.
        let distanceFromHipOnY = abs(footTransform.columns.3.y)
        return distanceFromHipOnY
    }
}
