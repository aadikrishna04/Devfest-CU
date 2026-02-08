import SceneKit
import SwiftUI

// MARK: - SwiftUI Wrapper

struct WireframeSceneView: UIViewRepresentable {
    let scenario: String
    let bpm: Int
    let isMetronomeActive: Bool
    let bodyRegion: String

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(frame: .zero)
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.allowsCameraControl = false
        v.isPlaying = true
        context.coordinator.setup(v)
        return v
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(
            scenario: scenario,
            bpm: bpm,
            bodyRegion: bodyRegion
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // =========================================================================
    // MARK: - Coordinator
    // =========================================================================

    class Coordinator {
        private var scene: SCNScene!
        private var cameraNode: SCNNode!
        private var characterRoot: SCNNode!
        private var gridNode: SCNNode!
        private var handsNode: SCNNode?
        private var highlightOverlays: [SCNNode] = []

        private var currentScenario = ""
        private var currentBPM = 0
        private var currentRegion = ""
        private var modelLoaded = false

        // Mixamo joint references (cached on load)
        private var joints: [String: SCNNode] = [:]

        // Body region → Mixamo joint names for highlighting
        private let regionJoints: [String: [String]] = [
            "head": ["mixamorig:Head"],
            "neck": ["mixamorig:Neck"],
            "chest": ["mixamorig:Spine1", "mixamorig:Spine2"],
            "abdomen": ["mixamorig:Spine"],
            "pelvis": ["mixamorig:Hips"],
            "left_arm": ["mixamorig:LeftShoulder", "mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand"],
            "right_arm": ["mixamorig:RightShoulder", "mixamorig:RightArm", "mixamorig:RightForeArm", "mixamorig:RightHand"],
            "left_leg": ["mixamorig:LeftUpLeg", "mixamorig:LeftLeg", "mixamorig:LeftFoot"],
            "right_leg": ["mixamorig:RightUpLeg", "mixamorig:RightLeg", "mixamorig:RightFoot"],
            "full_body": [],
        ]

        // Highlight overlay sphere radius per joint
        private let overlaySizes: [String: Float] = [
            "mixamorig:Head": 0.14,
            "mixamorig:Neck": 0.07,
            "mixamorig:Spine2": 0.20, "mixamorig:Spine1": 0.18,
            "mixamorig:Spine": 0.16, "mixamorig:Hips": 0.18,
            "mixamorig:LeftShoulder": 0.09, "mixamorig:RightShoulder": 0.09,
            "mixamorig:LeftArm": 0.07, "mixamorig:RightArm": 0.07,
            "mixamorig:LeftForeArm": 0.06, "mixamorig:RightForeArm": 0.06,
            "mixamorig:LeftHand": 0.05, "mixamorig:RightHand": 0.05,
            "mixamorig:LeftUpLeg": 0.10, "mixamorig:RightUpLeg": 0.10,
            "mixamorig:LeftLeg": 0.08, "mixamorig:RightLeg": 0.08,
            "mixamorig:LeftFoot": 0.06, "mixamorig:RightFoot": 0.06,
        ]

        // Primary joint to focus camera on per region
        private let regionFocusJoint: [String: String] = [
            "head": "mixamorig:Head",
            "neck": "mixamorig:Neck",
            "chest": "mixamorig:Spine2",
            "abdomen": "mixamorig:Spine1",
            "pelvis": "mixamorig:Hips",
            "left_arm": "mixamorig:LeftForeArm",
            "right_arm": "mixamorig:RightForeArm",
            "left_leg": "mixamorig:LeftLeg",
            "right_leg": "mixamorig:RightLeg",
        ]

        // ================================================================
        // MARK: - Setup
        // ================================================================

        func setup(_ view: SCNView) {
            scene = SCNScene()
            scene.background.contents = UIColor.clear
            view.scene = scene

            cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 36
            cameraNode.position = SCNVector3(0, 1.0, 3.0)
            cameraNode.look(at: SCNVector3(0, 0.85, 0))
            scene.rootNode.addChildNode(cameraNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 800
            ambient.light?.color = UIColor(white: 0.7, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            gridNode = makeGrid()
            scene.rootNode.addChildNode(gridNode)

            characterRoot = loadCharacter()
            scene.rootNode.addChildNode(characterRoot)

            if modelLoaded { startIdle() }
        }

        // ================================================================
        // MARK: - Model Loading
        // ================================================================

        private func loadCharacter() -> SCNNode {
            let candidates = [
                "Models.scnassets/ybot.fbx", "Models.scnassets/ybot.dae",
                "Models.scnassets/ybot.scn", "Models.scnassets/character.dae",
                "Models.scnassets/character.scn", "Models.scnassets/ybot.usdz",
                "ybot.fbx", "ybot.dae", "character.dae",
            ]
            for name in candidates {
                if let s = SCNScene(named: name) {
                    modelLoaded = true
                    return importModel(from: s)
                }
            }
            for ext in ["fbx", "dae", "scn", "usdz"] {
                for base in ["ybot", "character"] {
                    if let url = Bundle.main.url(forResource: base, withExtension: ext),
                       let s = try? SCNScene(url: url) {
                        modelLoaded = true
                        return importModel(from: s)
                    }
                }
            }
            modelLoaded = false
            return SCNNode()
        }

        private func importModel(from modelScene: SCNScene) -> SCNNode {
            let root = SCNNode()
            root.name = "characterRoot"
            for child in modelScene.rootNode.childNodes {
                root.addChildNode(child.clone())
            }
            root.enumerateChildNodes { [weak self] node, _ in
                guard let self else { return }
                if let geo = node.geometry {
                    geo.materials = geo.materials.map { _ in self.grayWireframe() }
                }
                if let name = node.name, name.hasPrefix("mixamorig:") {
                    self.joints[name] = node
                }
            }
            // Auto-scale: Mixamo models are ~175cm, we want ~1.75 SceneKit units
            let (minB, maxB) = root.boundingBox
            let height = Float(maxB.y - minB.y)
            if height > 10 {
                let s = 1.75 / height
                root.scale = SCNVector3(s, s, s)
            }
            return root
        }

        // ================================================================
        // MARK: - Update
        // ================================================================

        func update(scenario: String, bpm: Int, bodyRegion: String) {
            guard modelLoaded else { return }

            let changed = scenario != currentScenario || bodyRegion != currentRegion
            let bpmChanged = scenario == "cpr" && bpm != currentBPM && bpm > 0
            guard changed || bpmChanged else { return }

            currentScenario = scenario
            currentBPM = bpm
            currentRegion = bodyRegion

            // Full reset
            characterRoot.removeAllActions()
            resetPose()
            removeHighlights()
            handsNode?.removeFromParentNode()
            handsNode = nil
            restoreBodyMaterial()
            gridNode.isHidden = false
            cameraNode.constraints = nil

            switch scenario {
            case "cpr":
                animateCPR(bpm: max(bpm, 80))
            case "seizure", "recovery_position":
                animateRecoveryPosition()
            case "choking":
                animateChoking()
            case "bleeding", "wound_care", "burn", "fracture", "minor_injury",
                 "allergic_reaction", "other_emergency":
                let region = bodyRegion.isEmpty ? defaultRegion(for: scenario) : bodyRegion
                animateInjuryFocus(region: region)
            default:
                startIdle()
            }
        }

        private func defaultRegion(for scenario: String) -> String {
            switch scenario {
            case "bleeding": return "chest"
            case "wound_care", "burn": return "left_arm"
            case "fracture": return "left_leg"
            default: return "chest"
            }
        }

        // ================================================================
        // MARK: - Injury Focus (zoomed view of affected region only)
        // ================================================================

        private func animateInjuryFocus(region: String) {
            // Dim the whole body so only the highlighted area stands out
            dimBody()
            gridNode.isHidden = true

            // Bright highlights on the affected joints
            highlightRegion(region)

            // Zoom camera tight onto the region
            focusCamera(on: region)

            // Slow rotation; camera tracks the joint via constraint
            characterRoot.runAction(
                .repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 14))
            )
        }

        /// Zooms camera to tightly frame a specific body region
        private func focusCamera(on region: String) {
            let jointName = regionFocusJoint[region] ?? "mixamorig:Spine1"
            guard let joint = joints[jointName] else { return }

            let target = joint.worldPosition

            // Camera distance varies by body part size
            let dist: Float
            switch region {
            case "head", "neck": dist = 0.40
            case "left_arm", "right_arm": dist = 0.60
            case "left_leg", "right_leg": dist = 0.70
            default: dist = 0.80
            }

            // Offset camera to the appropriate side
            let side: Float = region.contains("left") ? 0.10
                : region.contains("right") ? -0.10 : 0.06

            let camPos = SCNVector3(
                Float(target.x) + side,
                Float(target.y) + dist * 0.2,
                Float(target.z) + dist
            )
            moveCam(to: camPos, lookAt: target)

            // Look-at constraint keeps camera tracking the joint during rotation
            let constraint = SCNLookAtConstraint(target: joint)
            constraint.isGimbalLockEnabled = true
            cameraNode.constraints = [constraint]
        }

        // ================================================================
        // MARK: - CPR (hands positioned at actual chest location)
        // ================================================================

        private func animateCPR(bpm: Int) {
            guard let hips = joints["mixamorig:Hips"] else { return }

            // Lay body flat
            hips.eulerAngles.x = -Float.pi / 2
            characterRoot.position = SCNVector3(0, 0.08, 0.4)

            // Relax arms to sides
            joints["mixamorig:LeftArm"]?.eulerAngles.z = -Float.pi / 6
            joints["mixamorig:RightArm"]?.eulerAngles.z = Float.pi / 6

            highlightRegion("chest")

            // Wait one frame for transforms to commit, then read joint positions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                guard let self else { return }
                self.placeCPRHands(bpm: bpm)
            }
        }

        private func placeCPRHands(bpm: Int) {
            // Read actual chest position from the posed model
            let chestPos: SCNVector3
            if let spine2 = joints["mixamorig:Spine2"] {
                chestPos = spine2.presentation.worldPosition
            } else {
                chestPos = SCNVector3(0, 0.25, -0.4) // fallback
            }

            // Camera: slightly elevated and to the side, focused on chest
            moveCam(
                to: SCNVector3(chestPos.x + 0.6, chestPos.y + 0.9, chestPos.z + 0.5),
                lookAt: chestPos
            )

            // Build wireframe rescuer hands
            let hands = buildRescuerHands()
            // Position palms directly above the chest
            hands.position = SCNVector3(chestPos.x, chestPos.y + 0.20, chestPos.z)
            scene.rootNode.addChildNode(hands)
            self.handsNode = hands

            // Compress synced to BPM
            let cycle = 60.0 / Double(bpm)
            let down = SCNAction.moveBy(x: 0, y: -0.10, z: 0, duration: cycle * 0.35)
            down.timingMode = .easeIn
            let hold = SCNAction.wait(duration: cycle * 0.10)
            let up = SCNAction.moveBy(x: 0, y: 0.10, z: 0, duration: cycle * 0.55)
            up.timingMode = .easeOut
            hands.runAction(.repeatForever(.sequence([down, hold, up])))
        }

        private func buildRescuerHands() -> SCNNode {
            let hands = SCNNode()

            let palmGeo = SCNBox(width: 0.14, height: 0.035, length: 0.12, chamferRadius: 0.008)
            palmGeo.widthSegmentCount = 3
            palmGeo.heightSegmentCount = 2
            palmGeo.lengthSegmentCount = 3

            let lp = SCNNode(geometry: palmGeo)
            lp.geometry?.firstMaterial = redWireframe()
            lp.position = SCNVector3(-0.008, 0, -0.008)
            let rp = SCNNode(geometry: palmGeo)
            rp.geometry?.firstMaterial = redWireframe()
            rp.position = SCNVector3(0.008, 0, 0.008)
            rp.eulerAngles.y = Float.pi / 15

            let wristGeo = SCNCapsule(capRadius: 0.025, height: 0.20)
            wristGeo.radialSegmentCount = 10
            wristGeo.firstMaterial = grayWireframe()
            let lw = SCNNode(geometry: wristGeo)
            lw.position = SCNVector3(-0.09, 0.12, 0.05)
            lw.eulerAngles.z = Float.pi / 6
            let rw = SCNNode(geometry: wristGeo)
            rw.position = SCNVector3(0.09, 0.12, 0.05)
            rw.eulerAngles.z = -Float.pi / 6

            hands.addChildNode(lp)
            hands.addChildNode(rp)
            hands.addChildNode(lw)
            hands.addChildNode(rw)
            return hands
        }

        // ================================================================
        // MARK: - Recovery Position (full body view for posture context)
        // ================================================================

        private func animateRecoveryPosition() {
            guard let hips = joints["mixamorig:Hips"] else { return }

            highlightRegion("head")

            // Start lying flat
            hips.eulerAngles.x = -Float.pi / 2
            characterRoot.position = SCNVector3(0, 0.08, 0.3)

            moveCam(to: SCNVector3(0, 2.4, 2.0), lookAt: SCNVector3(0, 0.08, -0.2))

            // Step 1: Roll onto side
            let rollDelay = SCNAction.wait(duration: 1.5)
            let roll = SCNAction.customAction(duration: 1.5) { [weak self] _, elapsed in
                guard let self else { return }
                let t = Float(elapsed / 1.5)
                hips.eulerAngles.z = t * (Float.pi / 2)
                self.characterRoot.position.y = 0.08 + t * 0.10
            }

            // Step 2: Pose limbs
            let poseLimbs = SCNAction.customAction(duration: 1.0) { [weak self] _, elapsed in
                guard let self else { return }
                let t = Float(elapsed / 1.0)
                // Top knee bent forward for stability
                self.joints["mixamorig:RightUpLeg"]?.eulerAngles.x = t * (Float.pi / 3)
                self.joints["mixamorig:RightLeg"]?.eulerAngles.x = t * (-Float.pi / 3)
                // Bottom arm extended
                self.joints["mixamorig:LeftArm"]?.eulerAngles.z = t * (-Float.pi / 3)
                // Top arm draped forward
                self.joints["mixamorig:RightArm"]?.eulerAngles.x = t * (Float.pi / 4)
                self.joints["mixamorig:RightForeArm"]?.eulerAngles.x = t * (-Float.pi / 3)
                // Head tilted back (open airway)
                self.joints["mixamorig:Head"]?.eulerAngles.x = t * (-Float.pi / 8)
            }

            // Step 3: Gentle breathing
            let breathe = SCNAction.customAction(duration: 2.0) { _, elapsed in
                let t = Float(elapsed / 2.0)
                hips.eulerAngles.z = Float.pi / 2 + sin(t * Float.pi) * 0.04
            }

            characterRoot.runAction(.sequence([
                rollDelay, roll, poseLimbs, .repeatForever(breathe),
            ]))
        }

        // ================================================================
        // MARK: - Choking (fist positioned at actual abdomen location)
        // ================================================================

        private func animateChoking() {
            highlightRegion("abdomen")

            // Read abdomen position from standing model
            let abdomenPos = joints["mixamorig:Spine"]?.worldPosition
                ?? SCNVector3(0, 0.55, 0)

            // Camera focused on abdomen area
            moveCam(
                to: SCNVector3(abdomenPos.x, abdomenPos.y + 0.08, abdomenPos.z + 1.0),
                lookAt: abdomenPos
            )

            let hands = SCNNode()
            let fistGeo = SCNSphere(radius: 0.045)
            fistGeo.segmentCount = 12
            fistGeo.firstMaterial = redWireframe()
            let fist = SCNNode(geometry: fistGeo)
            // Fist just in front of the abdomen
            fist.position = SCNVector3(abdomenPos.x, abdomenPos.y, abdomenPos.z + 0.14)
            hands.addChildNode(fist)

            let armGeo = SCNCapsule(capRadius: 0.025, height: 0.20)
            armGeo.radialSegmentCount = 10
            armGeo.firstMaterial = grayWireframe()
            let la = SCNNode(geometry: armGeo)
            la.position = SCNVector3(fist.position.x - 0.13, fist.position.y, fist.position.z - 0.04)
            la.eulerAngles.z = Float.pi / 4
            let ra = SCNNode(geometry: armGeo)
            ra.position = SCNVector3(fist.position.x + 0.13, fist.position.y, fist.position.z - 0.04)
            ra.eulerAngles.z = -Float.pi / 4
            hands.addChildNode(la)
            hands.addChildNode(ra)

            scene.rootNode.addChildNode(hands)
            self.handsNode = hands

            // Thrust motion
            let inward = SCNAction.move(by: SCNVector3(0, 0.05, -0.04), duration: 0.25)
            inward.timingMode = .easeIn
            let outward = SCNAction.move(by: SCNVector3(0, -0.05, 0.04), duration: 0.5)
            outward.timingMode = .easeOut
            let pause = SCNAction.wait(duration: 0.8)
            fist.runAction(.repeatForever(.sequence([inward, outward, pause])))
        }

        // ================================================================
        // MARK: - Idle
        // ================================================================

        private func startIdle() {
            moveCam(to: SCNVector3(0, 1.0, 3.0), lookAt: SCNVector3(0, 0.85, 0))
            characterRoot.runAction(
                .repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 18))
            )
        }

        // ================================================================
        // MARK: - Highlighting
        // ================================================================

        private func highlightRegion(_ region: String) {
            let jointNames: [String]
            if region == "full_body" {
                jointNames = Array(joints.keys)
            } else {
                jointNames = regionJoints[region] ?? []
            }
            for name in jointNames {
                guard let joint = joints[name] else { continue }
                let size = overlaySizes[name] ?? 0.10
                let sphere = SCNSphere(radius: CGFloat(size))
                sphere.segmentCount = 16
                sphere.firstMaterial = redGlow()

                let overlay = SCNNode(geometry: sphere)
                overlay.name = "highlight"
                overlay.opacity = 0.5

                let down = SCNAction.fadeOpacity(to: 0.2, duration: 0.6)
                down.timingMode = .easeInEaseOut
                let up = SCNAction.fadeOpacity(to: 0.5, duration: 0.6)
                up.timingMode = .easeInEaseOut
                overlay.runAction(.repeatForever(.sequence([down, up])))

                joint.addChildNode(overlay)
                highlightOverlays.append(overlay)
            }
        }

        private func removeHighlights() {
            for node in highlightOverlays { node.removeFromParentNode() }
            highlightOverlays.removeAll()
        }

        // ================================================================
        // MARK: - Body Material Control
        // ================================================================

        /// Dim entire mesh so only highlighted region stands out
        private func dimBody() {
            characterRoot.enumerateChildNodes { [weak self] node, _ in
                guard let self, node.geometry != nil else { return }
                node.geometry?.materials = node.geometry!.materials.map { _ in self.dimWireframe() }
            }
        }

        /// Restore normal wireframe brightness
        private func restoreBodyMaterial() {
            characterRoot.enumerateChildNodes { [weak self] node, _ in
                guard let self, node.geometry != nil else { return }
                node.geometry?.materials = node.geometry!.materials.map { _ in self.grayWireframe() }
            }
        }

        // ================================================================
        // MARK: - Materials
        // ================================================================

        private func grayWireframe() -> SCNMaterial {
            let m = SCNMaterial()
            m.fillMode = .lines
            m.diffuse.contents = UIColor(white: 0.55, alpha: 1)
            m.emission.contents = UIColor(white: 0.2, alpha: 1)
            m.isDoubleSided = true
            return m
        }

        /// Very faint wireframe for context (dimmed body)
        private func dimWireframe() -> SCNMaterial {
            let m = SCNMaterial()
            m.fillMode = .lines
            m.diffuse.contents = UIColor(white: 0.20, alpha: 0.12)
            m.emission.contents = UIColor(white: 0.06, alpha: 0.04)
            m.isDoubleSided = true
            return m
        }

        private func redWireframe() -> SCNMaterial {
            let m = SCNMaterial()
            m.fillMode = .lines
            m.diffuse.contents = UIColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 1)
            m.emission.contents = UIColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 0.6)
            m.isDoubleSided = true
            return m
        }

        private func redGlow() -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 0.3)
            m.emission.contents = UIColor(red: 1.0, green: 0.35, blue: 0.30, alpha: 0.8)
            m.isDoubleSided = true
            m.transparency = 0.4
            return m
        }

        // ================================================================
        // MARK: - Helpers
        // ================================================================

        private func makeGrid() -> SCNNode {
            let plane = SCNPlane(width: 6, height: 6)
            plane.widthSegmentCount = 30
            plane.heightSegmentCount = 30
            let m = SCNMaterial()
            m.fillMode = .lines
            m.diffuse.contents = UIColor(white: 0.35, alpha: 0.3)
            m.isDoubleSided = true
            plane.firstMaterial = m
            let n = SCNNode(geometry: plane)
            n.eulerAngles.x = -Float.pi / 2
            n.position = SCNVector3(0, -0.02, 0)
            return n
        }

        private func moveCam(to pos: SCNVector3, lookAt target: SCNVector3) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.6
            cameraNode.position = pos
            cameraNode.look(at: target)
            SCNTransaction.commit()
        }

        private func resetPose() {
            for (_, joint) in joints { joint.eulerAngles = SCNVector3Zero }
            characterRoot.eulerAngles = SCNVector3Zero
            characterRoot.position = SCNVector3Zero
        }
    }
}
