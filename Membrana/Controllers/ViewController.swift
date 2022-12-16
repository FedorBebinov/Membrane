//
//  ViewController.swift
//  Membrana
//
//  Created by Fedor Bebinov on 08.12.22.
//

import UIKit
import AVFoundation
import CoreHaptics
import Lottie

final class ViewController: UIViewController {

    // MARK : Properties
    var gestureTitleLabel = UILabel()
    var fingerprintImageView = UIImageView()
    var audioPlayer = AVAudioPlayer()
    var panGestureStartLocation : CGPoint = .zero
    var engine: CHHapticEngine?
    let animationView = LottieAnimationView()
    var repeatedPoinstCount = 0
    var isXChanged = false
    var isYChanged = false

    var model = MainModel()

    // MARK: Private funcs
    private func setUpView() {
        let backgroundImage = UIImage(named: MainModel.Images.backgroundImageName)
        let backgroundImageView = UIImageView(image: backgroundImage)
        view.addSubview(backgroundImageView)
        backgroundImageView.anchor(top: view.topAnchor, paddingTop: -100,
                                   bottom:  view.bottomAnchor, paddingBottom: 100,
                                   left: view.leadingAnchor, paddingLeft: 0,
                                   right: view.trailingAnchor, paddingRight: 0)

        animationView.frame = view.bounds
        animationView.isHidden = true
        view.addSubview(animationView)

        view.addSubview(gestureTitleLabel)
        gestureTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        gestureTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16).isActive = true
        gestureTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        gestureTitleLabel.font = .systemFont(ofSize: 40, weight: .bold)
        gestureTitleLabel.textColor = .white
        self.gestureTitleLabel.alpha = 0

        fingerprintImageView.image = model.fingerPrintImage
        view.addSubview(fingerprintImageView)
        fingerprintImageView.frame.size = CGSize(width: 70, height: 70)
        fingerprintImageView.layer.cornerRadius = 35
        fingerprintImageView.clipsToBounds = true
        self.fingerprintImageView.alpha = 0
    }

    private func setEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the engine: \(error.localizedDescription)")
        }

        engine?.stoppedHandler = { reason in
            print("The engine stopped: \(reason)")
        }

        // If something goes wrong, attempt to restart the engine immediately
        engine?.resetHandler = { [weak self] in
            print("The engine reset")

            do {
                try self?.engine?.start()
            } catch {
                print("Failed to restart the engine: \(error)")
            }
        }
    }

    private func createHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 3)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play pattern: \(error.localizedDescription).")
        }
    }

    private func addGestures() {
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        view.addGestureRecognizer(singleTap)

        let doubleTap = UITapGestureRecognizer(target: self, action:  #selector(self.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_ :)))
        panGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(panGesture)

        //        let longPress = UILongPressGestureRecognizer(target: self, action:  #selector(self.handleLongPress(_:)))
        //        view.addGestureRecognizer(longPress)
        //

        singleTap.require(toFail: doubleTap)
    }

    private func playSound(named: String, type: String) {
        let path = Bundle.main.path(forResource: named, ofType: type)!
        let url = URL(fileURLWithPath: path)

        do {
            //create your audioPlayer in your parent class as a property
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.play()
        } catch {
            print("couldn't load the file")
        }
    }

    private func animateTitle(named: String) {
        gestureTitleLabel.text = named
        UIView.animate(withDuration: 0.5, animations : {
            self.gestureTitleLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 2.5, animations : {
                self.gestureTitleLabel.alpha = 0
            })
        }
    }

    private func addLottieAnimation(named: String) {
        animationView.isHidden = false
        animationView.animation = LottieAnimation.named(named)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        animationView.play(){ [weak self] _ in
            self?.animationView.isHidden = true
        }
    }

    // MARK: View controller life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
        addGestures()
        setEngine()
    }

    // MARK: IBActions
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        animateTitle(named: MainModel.GestureTitle.contact)

        fingerprintImageView.center = sender?.location(in: view) ?? CGPoint.zero
        UIView.animate(withDuration: 2, animations : {
            self.fingerprintImageView.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.5, animations : {
                self.fingerprintImageView.alpha = 0
            })
        }
    }

    @objc func handlePan(_ sender: UIPanGestureRecognizer? = nil) {
        guard let position = sender?.location(in: view) else { return }

        if sender?.state == .began {
            panGestureStartLocation = position
            isXChanged = false
            isYChanged = false
        }

        if sender?.state == .changed {
            if (position.x - panGestureStartLocation.x).magnitude > 50 {
                isXChanged = true
            }
            if (position.y - panGestureStartLocation.y).magnitude > 50 {
                isYChanged = true
            }

        }

        if sender?.state == .ended {
            if position.y - panGestureStartLocation.y > view.frame.size.height - 200 {
                animateTitle(named: MainModel.GestureTitle.grom)
                createHaptic()
                playSound(named: MainModel.Sound.grom.0, type: MainModel.Sound.grom.1)
                addLottieAnimation(named: MainModel.LottieNamed.lightning)
            }

            if isXChanged && isYChanged {
                let distance = position.cgPointDistance(to: panGestureStartLocation)
                if distance >= 0 && distance <= 50 {
                    animateTitle(named: MainModel.GestureTitle.dojd)
                    playSound(named: MainModel.Sound.dojd.0, type: MainModel.Sound.dojd.1)
                    addLottieAnimation(named: MainModel.LottieNamed.rain)
                }
            }
        }
    }


//    @objc func handleLongPress(_ sender: UITapGestureRecognizer? = nil) {
//    }

    @objc func handleDoubleTap(_ sender: UITapGestureRecognizer? = nil) {
        animateTitle(named: MainModel.GestureTitle.svet)
        playSound(named: MainModel.Sound.solnce.0, type: MainModel.Sound.solnce.1)
        addLottieAnimation(named: MainModel.LottieNamed.double_tap)
    }
}

