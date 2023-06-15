//
//  DialerViewController.swift
//  inapp-voice
//
//  Created by iujie on 19/04/2023.
//

import UIKit
import AVFoundation

enum AudioRoute: Int {
    case Headphones
    case Speaker
    case Bluetooth
    case Receiver
    case None
}


class CallViewController: UIViewController {
    
    // Idle Call View
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var idleCallStackView: UIStackView!
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var memberSearchTextField: UITextField!
    @IBOutlet weak var memberTableView: UITableView!
    @IBOutlet weak var logoutButton: UIButton!
    
    // Active Call View
    @IBOutlet weak var activeCallStackView: UIStackView!
    @IBOutlet weak var callMemberLabel: UILabel!
    @IBOutlet weak var callStatusLabel: UILabel!
    @IBOutlet weak var ringingStackView: UIStackView!
    @IBOutlet weak var answeredStackView: UIStackView!
    @IBOutlet weak var answerButton: UIButton!
    @IBOutlet weak var rejectButton: UIButton!
    @IBOutlet weak var hangupButton: UIButton!
    @IBOutlet weak var micButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    
    var user: UserModel!
    var userManager = UserManager()
    
    var isMembersLoading = false
    var memberList: MemberModel!
    var membersManager = MembersManager()
    var memberSearchResult = [String]()
    
    var activeOutput: AudioRoute = .None {
        didSet {
            displayActiveOutput(activeOutput: activeOutput)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        if let data = UserDefaults.standard.data(forKey: Constants.userKey) {
            do {
                let decoder = JSONDecoder()
                let user = try decoder.decode(UserModel.self, from: data)
                self.user = user
                setupInitialView()
                
            } catch {
                self.present(createAlert(message: "Unable to Decode user: \(error)", completion: { isActionSubmitted in
                    self.dismiss(animated: true)
                }), animated: true)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupInitialView() {
        // Initial View - title
        usernameLabel.text = "\(user.username) (\(user.region))"
        
        // Initial View - Action Button
        answerButton.layer.cornerRadius = Constants.borderRadius
        rejectButton.layer.cornerRadius = Constants.borderRadius
        callButton.layer.cornerRadius = Constants.borderRadius
        hangupButton.layer.cornerRadius = Constants.borderRadius
        speakerButton.layer.cornerRadius = Constants.borderRadius
        micButton.layer.cornerRadius = Constants.borderRadius
        displayMicState(isMuted: appDelegate.vgclient.isMuted)
        
        speakerButton.menu = generateAudioOutputMenu()
        speakerButton.showsMenuAsPrimaryAction = true

        // Initial View - Members
        memberSearchTextField.delegate = self
        memberTableView.dataSource = self
        memberTableView.delegate = self
        membersManager.delegate = self
        loadMembers()
        
        // get current call state
        let currentCallStatus = self.appDelegate.vgclient.currentCallStatus
        if let callStatus = currentCallStatus {
            self.updateCallStateUI(callStatus: callStatus)
        }
        
        // notification
        NotificationCenter.default.addObserver(self, selector: #selector(connectionStatusReceived(_:)), name: .clientStatus, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(callReceived(_:)), name: .callStatus, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateCallMembersStatus(_:)), name: .updateCallMembersStatus, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateMic(_:)), name: .micState, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        memberSearchTextField.endEditing(true)
    }
    
    private func loadMembers() {
        if (isMembersLoading) {return}
        isMembersLoading = true
        membersManager.fetchMembers(user: user)
    }
    
    private func updateCallStateUI(callStatus: CallStatusModel) {
        switch callStatus.state {
        case .answered, .ringing:
            displayActiveCall(state: callStatus.state, type: callStatus.type, member: callStatus.member)
        case .completed:
            displayIdleCall(message: callStatus.message)
        }
    }
    private func displayActiveCall(state: CallState, type: CallType?, member: String?) {
        DispatchQueue.main.async { [weak self] in
            if (self == nil) {return}
            
            self!.logoutButton.isHidden = true
            self!.idleCallStackView.isHidden = true
            self!.activeCallStackView.isHidden = false
            
            self!.ringingStackView.isHidden = true
            self!.answeredStackView.isHidden = false
                        
            if (member != nil) {
                self!.callMemberLabel.text = member
            }
            
            if (state == .ringing) {
                self!.callStatusLabel.text = "Ringing"
                
                if (type == .inbound) {
                    self!.ringingStackView.isHidden = false
                    self!.answeredStackView.isHidden = true
                }
            }
            if (state == .answered) {
                self!.callStatusLabel.text = "Answered"
            }
        }
    }
    
    private func displayIdleCall(message: String?) {
        DispatchQueue.main.async { [weak self] in
            if (self == nil) {return}
            
            self!.logoutButton.isHidden = false
            if (message != nil) {
                self!.present(createAlert(message: message!, completion: { isActionSubmitted in
                    self!.idleCallStackView.isHidden = false
                    self!.activeCallStackView.isHidden = true
                }), animated: true, completion: nil)
            }
            else {
                self!.idleCallStackView.isHidden = false
                self!.activeCallStackView.isHidden = true
            }
        }
    }
    
    private func disableActionButtons() {
        hangupButton.isEnabled = false
        micButton.isEnabled = false
        speakerButton.isEnabled = false
        answerButton.isEnabled = false
        rejectButton.isEnabled = false
        callButton.isEnabled = false
    }
    
    private func enableActionButton() {
        hangupButton.isEnabled = true
        micButton.isEnabled = true
        speakerButton.isEnabled = true
        answerButton.isEnabled = true
        rejectButton.isEnabled = true
        callButton.isEnabled = true
    }
    private func displayMicState(isMuted: Bool) {
        if (isMuted) {
            micButton.tintColor = .black
        }
        else {
            micButton.tintColor = .systemGray3
        }
    }
    
    private func displayActiveOutput(activeOutput: AudioRoute) {
        speakerButton.tintColor = .black
        
        switch activeOutput {
        case .Headphones:
            speakerButton.setImage(UIImage(systemName: "headphones"), for: .normal)
            speakerButton.setTitle("Headphone", for: .normal)
        case .Speaker:
            speakerButton.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
            speakerButton.setTitle("Speaker", for: .normal)
        case .Receiver:
            speakerButton.setImage(UIImage(systemName: "iphone"), for: .normal)
            speakerButton.setTitle("iPhone", for: .normal)
        case .Bluetooth:
            speakerButton.setImage(UIImage(systemName: "airpods"), for: .normal)
            speakerButton.setTitle("Bluetooth", for: .normal)
        case .None:
            speakerButton.tintColor = .systemGray3
        }
    }

    private func logout() {
        if let user = user {
            userManager.deleteUser(user: user)
        }
        appDelegate.vgclient.logout()
        dismiss(animated: true)
    }
}

//MARK: Notifications
extension CallViewController {
    @objc func callReceived(_ notification: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            if let callStatus = notification.object as? CallStatusModel {
                if (self ==  nil) {return}
                self!.enableActionButton()
                self!.updateCallStateUI(callStatus: callStatus)
            }
        }
    }
    
    @objc func connectionStatusReceived(_ notification: NSNotification) {
        if let clientStatus = notification.object as? VonageClientStatusModel {
            DispatchQueue.main.async { [weak self] in
                if (self == nil) {return}
                
                if (clientStatus.state == .disconnected) {
                    if clientStatus.message != nil {
                        self!.present(createAlert(message: clientStatus.message!, completion: { isActionSubmitted in
                            self!.logout()
                        }), animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    @objc func updateCallMembersStatus(_ notification: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            if (self == nil) {return}
            if (!self!.idleCallStackView.isHidden && ( self!.memberSearchTextField.text != "" || !self!.memberTableView.isHidden)) {
                self!.loadMembers()
            }
        }
    }
    
    @objc func updateMic(_ notification: NSNotification) {
        if let isMuted = notification.object as? Bool {
            DispatchQueue.main.async { [weak self] in
                if (self == nil) {return}
                self!.displayMicState(isMuted: isMuted)
            }
        }
    }
    
    @objc func handleAudioRouteChange(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo,
             let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
             let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                 return
         }
         
         switch reason {
         case .newDeviceAvailable: // New device found.
             speakerButton.menu = generateAudioOutputMenu()
         case .oldDeviceUnavailable: // Old device removed.
             speakerButton.menu = generateAudioOutputMenu()

         default: ()
         }
    }
}

//MARK: Actions
extension CallViewController {
    @IBAction func onCallbuttonClicked(_ sender: Any) {
        if (memberSearchTextField.text == "") {
            self.showToast(message: "Please select a member", font: .systemFont(ofSize: 12.0))
            return
        }
        let member = memberSearchTextField.text!
        if (!memberList.members.contains(member)) {
            self.showToast(message: "Invalid member Or User busy", font: .systemFont(ofSize: 12.0))
            return
        }
        disableActionButtons()
        memberSearchTextField.endEditing(true)
        appDelegate.vgclient.startOutboundCall(user: user, member: member)
    }
    
    @IBAction func answerCallClicked(_ sender: Any) {
        disableActionButtons()
        appDelegate.vgclient.answerByCallkit(calluuid: appDelegate.vgclient.currentCallStatus?.uuid)
    }
    
    @IBAction func rejectCallClicked(_ sender: Any) {
        disableActionButtons()
        appDelegate.vgclient.rejectByCallkit(calluuid: appDelegate.vgclient.currentCallStatus?.uuid)
    }
    
    @IBAction func hangupCallClicked(_ sender: Any) {
        disableActionButtons()
        appDelegate.vgclient.hangUpCall(callId: appDelegate.vgclient.currentCallStatus?.uuid?.toVGCallID())
    }

    @IBAction func micButtonClicked(_ sender: Any) {
        appDelegate.vgclient.toggleMute(calluuid: appDelegate.vgclient.currentCallStatus?.uuid)
    }
    
    func generateAudioOutputMenu() -> UIMenu {
        // Pull active audio output
        let availableAudioPorts = AVAudioSession.sharedInstance().availableInputs
        let currentOutput = AVAudioSession.sharedInstance().currentRoute.outputs
        
        var headphonesExist = false
        var builtInAudioDevice: AVAudioSessionPortDescription? = nil
        
        var menuActions: [UIAction] = []
        for audioPort in availableAudioPorts! {
            switch audioPort.portType {
                case AVAudioSession.Port.bluetoothA2DP, AVAudioSession.Port.bluetoothHFP, AVAudioSession.Port.bluetoothLE :
                    if (currentOutput.contains(where: {return $0.portType == audioPort.portType})) {
                        activeOutput = .Bluetooth
                    }
                menuActions.append(UIAction(title: audioPort.portName, image: UIImage(systemName: "airpods"), state: currentOutput.contains(where: {return $0.portType == audioPort.portType}) ? .on : .off) { (action) in
                                do {
                                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.none)
                                    self.speakerButton.menu = nil
                                    self.speakerButton.menu = self.generateAudioOutputMenu()

                                } catch {
                                    print("\(String(describing: error))")
                                }
                            })
                    break
                case AVAudioSession.Port.builtInMic, AVAudioSession.Port.builtInReceiver:
                    builtInAudioDevice = audioPort
                    break
                case AVAudioSession.Port.headphones, AVAudioSession.Port.headsetMic:
                    headphonesExist = true
                    if (currentOutput.contains(where: {return $0.portType == AVAudioSession.Port.headphones}) || currentOutput.contains(where: {return $0.portType == AVAudioSession.Port.headsetMic})) {
                        activeOutput = .Headphones
                    }
                    
                    menuActions.append(UIAction(title: audioPort.portName, image: UIImage(systemName: "headphones"), state:  currentOutput.contains(where: {return $0.portType == AVAudioSession.Port.headphones}) || currentOutput.contains(where: {return $0.portType == AVAudioSession.Port.headsetMic}) ? .on : .off) { (action) in
                                do {
                                    try AVAudioSession.sharedInstance().setPreferredInput(audioPort)
                                    self.speakerButton.menu = nil
                                    self.speakerButton.menu = self.generateAudioOutputMenu()
                                } catch {
                                    print("\(String(describing: error))")
                                }
                        })
                    break
                default:
                    break
            }

        }
        
        // Add iPhone
        if !headphonesExist && builtInAudioDevice != nil {
            
            if (currentOutput.contains(where: {return $0.portType == AVAudioSession.Port.builtInReceiver}) || currentOutput.contains(where: {return $0.portType == AVAudioSession.Port.builtInMic})) {
                activeOutput = .Receiver
            }
            
            menuActions.append(UIAction(title: "iPhone", image: UIImage(systemName: "iphone"), state: currentOutput.contains(where: {return $0.portType == AVAudioSession.Port.builtInReceiver}) || currentOutput.contains(where: {return $0.portType == AVAudioSession.Port.builtInMic}) ? .on : .off) { (action) in
                    do {
                        // remove speaker if needed
                        try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.none)
                        // set new input
                        try AVAudioSession.sharedInstance().setPreferredInput(builtInAudioDevice)
                        self.speakerButton.menu = nil
                        self.speakerButton.menu = self.generateAudioOutputMenu()
                    } catch {
                        print("\(String(describing: error))")
                    }
                })
         }
        
        
        // Add Speaker
        if (currentOutput.contains(where: {return $0.portType == AVAudioSession.Port.builtInSpeaker})) {
            activeOutput = .Speaker
        }
        menuActions.append(UIAction(title: "Speaker", image: UIImage(systemName: "speaker.wave.2.fill"), state: currentOutput.contains(where: {return $0.portType == AVAudioSession.Port.builtInSpeaker})  ? .on : .off) { (action) in
            do {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
                self.speakerButton.menu = nil
                self.speakerButton.menu = self.generateAudioOutputMenu()

            } catch {
                print("\(String(describing: error))")
            }
        })
                
//        let menu = UIMenu(title: "Audio Output", options: .displayInline, children: menuActions)
        let menu = UIMenu(title: "Audio Output", children: [UIDeferredMenuElement({completion in
            completion([UIMenu(title: "", options: UIMenu.Options.displayInline, children: menuActions)])
//            self.speakerButton.menu = self.generateAudioOutputMenu()
            })
        ])
        return menu
    }
    
    @IBAction func onLogoutButtonClicked(_ sender: Any) {
        logout()
    }
}

//MARK: MembersManagerDelegate
extension CallViewController: MembersManagerDelegate {
    func didUpdateMembers(memberList: MemberModel) {
        DispatchQueue.main.async { [weak self] in
            if (self == nil) {return}
            self!.isMembersLoading = false
            self!.memberList = memberList
            self!.memberSearchResult = memberList.members
            self!.memberTableView.reloadData()
        }
    }
    
    func handleMembersManagerError(message: String) {
        DispatchQueue.main.async { [weak self] in
            if (self == nil) {return}
            
            self!.isMembersLoading = false
            
            self!.showToast(message: message, font: .systemFont(ofSize: 12.0))
        }
    }
}

//MARK: UITextFieldDelegate
extension CallViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        memberTableView.isHidden = false
        loadMembers()
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        memberTableView.isHidden = true
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        memberSearchResult = filterMembers(input: memberSearchTextField.text!)
        memberTableView.reloadData()
        textField.endEditing(true)
        return true
    }
    func textFieldDidChangeSelection(_ textField: UITextField) {
        memberSearchResult = filterMembers(input: memberSearchTextField.text!)
        memberTableView.reloadData()
    }
    
    func filterMembers(input: String) -> Array<String> {
        if input != "" && !memberList.members.contains(input){
            return memberList.members.filter({ member in
                member.lowercased().contains(input.lowercased())
            })
        }
        else {
            return memberList.members
        }
    }
}

//MARK: UITableViewDataSource
extension CallViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "memberTableCell")
        
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "memberTableCell")
        }
        
        if #available(iOS 14.0, *) {
            var config = UIListContentConfiguration.cell()
            config.text = memberSearchResult[indexPath.row]
            cell?.contentConfiguration = config
        } else {
            cell?.textLabel?.text = memberSearchResult[indexPath.row]
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return memberSearchResult.count
    }
}

//MARK: UITableViewDelegate
extension CallViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        memberSearchTextField.text = memberSearchResult[indexPath.row]
        memberSearchTextField.endEditing(true)
    }
}
