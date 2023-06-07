//
//  DataChildViewController.swift
//  inapp-voice
//
//  Created by iujie on 20/04/2023.
//

import UIKit

class DataChildViewController: UIViewController {
    
    @IBOutlet weak var memberLegStackView: UIStackView!
    
    @IBOutlet weak var myLegTitle: UILabel!
    @IBOutlet weak var memberLegTitle: UILabel!
    
    @IBOutlet weak var myLegId: UILabel!
    @IBOutlet weak var memberLegId: UILabel!
    
    @IBOutlet weak var region: UILabel!
    
    @IBOutlet weak var copyButton: UIButton!
    
    var callData: CallDataModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initial view
        copyButton.layer.cornerRadius = Constants.borderRadius
        copyButton.layer.borderColor = UIColor.black.cgColor
        copyButton.layer.borderWidth = 1
        view.layer.borderWidth = 2
        view.layer.borderColor = .init(red: 196/255, green: 53/255, blue: 152/255, alpha: 1)
        
        // Get current callData
        let currentCallData = appDelegate.vgclient.currentCallData
        
        if let callData = currentCallData {
            updateData(callData: callData)
        } else {
            view.isHidden = true
        }

        NotificationCenter.default.addObserver(self, selector: #selector(callDataReceived(_:)), name: .handledCallData, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateData(callData: CallDataModel) {
        view.isHidden = false
        self.callData = callData
        myLegTitle.text = "my LegId - \(callData.username)"
        myLegId.text = callData.myLegId
        region.text = callData.region
        memberLegTitle.text = "member LegId - \(callData.memberName)"
        
        if (callData.memberLegId != nil) {
            memberLegId.text = callData.memberLegId
            memberLegStackView.isHidden = false
        }
        else {
            memberLegStackView.isHidden = true
        }
    }
    
    @objc func callDataReceived(_ notification: NSNotification) {
        if let callData = notification.object as? CallDataModel {
            DispatchQueue.main.async { [weak self] in
                if (self == nil) {return}
                self!.updateData(callData: callData)
                
            }
        }
    }
    
    @IBAction func copyButtonClicked(_ sender: Any) {
        if let callData = callData {
            let memberLegId = callData.memberLegId == nil ? "nil" : callData.memberLegId!
            let copiedString = " myLegId - \(callData.username) : \(callData.myLegId), memberLegId - \(callData.memberName) : \(memberLegId), region: \( callData.region)"
            UIPasteboard.general.string = copiedString
            
            // show toast
            self.showToast(message: "Copied", font: .systemFont(ofSize: 12.0))
        }
    }
    
}
