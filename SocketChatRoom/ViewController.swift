//
//  ViewController.swift
//  SocketChatRoom
//
//  Created by 何家瑋 on 2017/10/26.
//  Copyright © 2017年 何家瑋. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

        @IBOutlet weak var userListTableView: UITableView!
        var userName : String? {
                didSet {
                        UserDefaults.standard.set(userName, forKey: "userName")
                        UserDefaults.standard.synchronize()
                        self.navigationItem.title = userName
                }
        }
        
        var userUUID : String? {
                didSet {
                        UserDefaults.standard.set(userUUID, forKey: "userUUID")
                        UserDefaults.standard.synchronize()
                }
        }
        
        var userList = [UserInfo]() {
                didSet {
                        DispatchQueue.main.async {
                                self.userListTableView.reloadData()
                        }
                }
        }
        
        var didSelectUsers = [String]() {
                didSet {
                        print("did select user : \(didSelectUsers)")
                }
        }
        
        var startSelect : Bool = false {
                didSet {
                        DispatchQueue.main.async {
                                self.userListTableView.reloadData()
                        }
                }
        }
        
        override func viewDidLoad() {
                super.viewDidLoad()
                // Do any additional setup after loading the view, typically from a nib.
                configureNavigation()
                userListTableView.dataSource = self
                userListTableView.delegate = self
        }
        
        override func viewDidAppear(_ animated: Bool) {
                super.viewDidAppear(animated)
                getUserUUID()
                logInWithUserName()
                SocketManager.Manager.getUserList { (userList) in
                        self.userList = userList
                }
        }
        
        func configureNavigation() {
                // maybe some day will support invite some one
                let addButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(selectUser))
                self.navigationItem.leftBarButtonItem = addButton
        }

        override func didReceiveMemoryWarning() {
                super.didReceiveMemoryWarning()
                // Dispose of any resources that can be recreated.
        }

        // MARK: - action
        func logInWithUserName() {
                guard userName == nil else { return }
                if let name = UserDefaults.standard.string(forKey: "userName") {
                        self.userName = name
                        SocketManager.Manager.login(name: self.userName!, uuid: self.userUUID!)
                } else {
                        let alertController = UIAlertController(title: "輸入使用者名稱", message: nil, preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "確認", style: .destructive, handler: { (okAction) in
                                let textField = alertController.textFields![0]
                                if textField.text?.count != 0 {
                                        self.navigationController?.title = textField.text
                                        self.userName = textField.text
                                } else {
                                        self.userName = "Vistor"
                                }
                                
                                SocketManager.Manager.login(name: self.userName!, uuid: self.userUUID!)
                        })
                        
                        alertController.addTextField(configurationHandler: nil)
                        alertController.addAction(okAction)
                        self.present(alertController, animated: true, completion: nil)
                }
        }
        
        func getUserUUID() {
                if let uuid = UserDefaults.standard.string(forKey: "userUUID") {
                        self.userUUID = uuid
                } else {
                        self.userUUID = NSUUID().uuidString
                }
        }
        
        // bar button action
        @objc func selectUser() {
                startSelect = true
                let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel , target: self, action: #selector(didFinishSelect))
                self.navigationItem.leftBarButtonItem = cancelButton
                let donelButton = UIBarButtonItem(barButtonSystemItem: .done , target: self, action: #selector(didFinishSelect))
                self.navigationItem.rightBarButtonItem = donelButton
        }
        
        @objc func didFinishSelect() {
                startSelect = false
                let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(selectUser))
                self.navigationItem.leftBarButtonItem = addButton
                self.navigationItem.rightBarButtonItem = nil
        }
}

// MARK: - UITableViewDelegate
extension ViewController : UITableViewDataSource, UITableViewDelegate {
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
                return userList.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as! UserCell
                let info = userList[indexPath.row]
                cell.nameLabel.text = info.userName
                cell.detailLabel.text = (info.isConnected) ? "online" : "offline"
                cell.detailLabel.textColor = (info.isConnected) ? UIColor.green : UIColor.red
                cell.displaySelectButton(show: startSelect)
                return cell
        }
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
                if startSelect {
                        let cell = tableView.cellForRow(at: indexPath) as! UserCell
                        let shouldSelect = (cell.didSelect) ? false : true
                        cell.didSelect = shouldSelect
                        
                        let info = userList[indexPath.row]
                        if shouldSelect {
                                didSelectUsers.append(info.socketID)
                        } else {
                                if let index = didSelectUsers.index(of: info.socketID) {
                                        didSelectUsers.remove(at: index)
                                }
                        }
                }
        }
        
        func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
                return 50
        }
}

// MARK: - UITableViewCell
class UserCell : UITableViewCell {
        private var selectButtonWidthConstraint : NSLayoutConstraint!
        var didSelect : Bool = false {
                didSet {
                        updateImage()
                }
        }
        
        let nameLabel : UILabel = {
                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                return label
        }()
        
        let detailLabel : UILabel = {
                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                label.textAlignment = .right
                return label
        }()
        
        private let selectImageView : UIImageView = {
                let imageView = UIImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                return imageView
        }()
        
        required init?(coder aDecoder: NSCoder) {
                super.init(coder: aDecoder)
                setupUIConstraint()
        }
        
        override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
                super.init(style: style, reuseIdentifier: reuseIdentifier)
                setupUIConstraint()
        }
        
        private func setupUIConstraint() {
                self.addSubview(selectImageView)
                self.addSubview(nameLabel)
                self.addSubview(detailLabel)
                
                selectButtonWidthConstraint = selectImageView.widthAnchor.constraint(equalToConstant: 0)
                NSLayoutConstraint.activate([
                        selectImageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                        selectImageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                        selectImageView.heightAnchor.constraint(equalToConstant: 30),
                        selectButtonWidthConstraint,

                        detailLabel.topAnchor.constraint(equalTo: self.topAnchor),
                        detailLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                        detailLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                        detailLabel.widthAnchor.constraint(equalToConstant: 70),
                        detailLabel.heightAnchor.constraint(equalToConstant: self.frame.size.height),

                        nameLabel.topAnchor.constraint(equalTo: self.topAnchor),
                        nameLabel.leadingAnchor.constraint(equalTo: selectImageView.trailingAnchor, constant: 10),
                        nameLabel.trailingAnchor.constraint(equalTo: detailLabel.leadingAnchor),
                        nameLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                        nameLabel.heightAnchor.constraint(equalToConstant: self.frame.size.height),
                        ])
        }
        
        private func updateImage() {
                let imageName = (didSelect) ? "checkmark-select.png" : "checkmark.png"
                selectImageView.image = UIImage(named: imageName)
        }
        
        func displaySelectButton(show : Bool) {
                let constant : CGFloat = (show) ? 30 : 0
                selectButtonWidthConstraint.constant = constant
                UIView.animate(withDuration: 0, delay: 0, options: .curveEaseOut, animations: {
                        self.layoutIfNeeded()
                }, completion: { (completed) in
                        self.didSelect = false
                })
        }
}

