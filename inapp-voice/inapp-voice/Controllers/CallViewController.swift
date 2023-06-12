//
//  DialerViewController.swift
//  inapp-voice
//
//  Created by iujie on 19/04/2023.
//

import UIKit

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
    @IBOutlet weak var answerButton: UIButton!
    @IBOutlet weak var rejectButton: UIButton!
    @IBOutlet weak var hangupButton: UIButton!
    
    var user: UserModel!
    var userManager = UserManager()
    
    var isMembersLoading = false
    var memberList: MemberModel!
    var membersManager = MembersManager()
    var memberSearchResult = [String]()
    
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
            self!.hangupButton.isHidden = false
            
            if (member != nil) {
                self!.callMemberLabel.text = member
            }
            
            if (state == .ringing) {
                self!.callStatusLabel.text = "Ringing"
                
                if (type == .inbound) {
                    self!.ringingStackView.isHidden = false
                    self!.hangupButton.isHidden = true
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
        answerButton.isEnabled = false
        rejectButton.isEnabled = false
        callButton.isEnabled = false
    }
    
    private func enableActionButton() {
        hangupButton.isEnabled = true
        answerButton.isEnabled = true
        rejectButton.isEnabled = true
        callButton.isEnabled = true
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
