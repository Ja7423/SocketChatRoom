//
//  ChatListViewController.swift
//  SocketChatRoom
//
//  Created by 何家瑋 on 2017/11/10.
//  Copyright © 2017年 何家瑋. All rights reserved.
//

import UIKit

class ChatListViewController: UITableViewController {
        var userName : String! {
                didSet {
                        self.navigationItem.title = userName
                }
        }
        
        var noPassword : String {
                get {
                        return "None"
                }
        }
        
        var roomList = [RoomInfo]() {
                didSet {
                        DispatchQueue.main.async {
                                self.tableView.reloadData()
                        }
                }
        }
        
        override func viewDidLoad() {
                super.viewDidLoad()
                configureNavigation()
        }
        
        override func viewDidAppear(_ animated: Bool) {
                self.tabBarController?.tabBar.isHidden = false
                super.viewDidAppear(animated)
                userName = UserDefaults.standard.string(forKey: "userName")!
                SocketManager.Manager.getRoomList { (roomList) in
                        self.roomList = roomList
                }
        }
        
        func configureNavigation() {
                let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewRoom))
                self.navigationItem.leftBarButtonItem = addButton
        }
        
        @objc func addNewRoom() {
                let alertController = UIAlertController(title: "create new room", message: nil, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "ok", style: .default) { (action) in
                        let nameTextField = alertController.textFields![0]
                        let passwordTextField = alertController.textFields![1]
                        if nameTextField.text?.count != 0 {
                                let roomName = nameTextField.text
                                let password = (passwordTextField.text?.count != 0) ? passwordTextField.text! : self.noPassword
                                SocketManager.Manager.createNewRoom(creator: self.userName, roomName: roomName!, password: password) { (success, content) in
                                        if success {
                                                let updateInfo = RoomInfo.infoWith(data: content)
                                                let chatRoomVC = ChatRoomViewController(roomInfo: updateInfo)
                                                self.navigationController?.pushViewController(chatRoomVC, animated: true)
                                        }
                                }
                        }
                }
                alertController.addAction(okAction)
                
                let cancelAction = UIAlertAction(title: "cancel", style: .destructive, handler: nil)
                alertController.addAction(cancelAction)
                
                alertController.addTextField { (textField) in
                        textField.placeholder = "name"
                }
                
                alertController.addTextField { (textField) in
                        textField.placeholder = "password (optional)"
                }
                
                self.present(alertController, animated: true, completion: nil)
        }
        
        override func didReceiveMemoryWarning() {
                super.didReceiveMemoryWarning()
                // Dispose of any resources that can be recreated.
        }
}

// MARK: - UITableViewDelegate
extension ChatListViewController {
        override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
                return roomList.count
        }
        
        override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: "ChatListCell", for: indexPath) as! ChatListCell
                let info = roomList[indexPath.row]
                let imageName = (info.password == noPassword) ? "unlock.png" : "lock.png"
                cell.lockImageView.image = UIImage(named: imageName)
                cell.nameLabel.text = info.roomName
                return cell
        }
        
        func promptIfNeedPassword(islock : Bool, completionHandler : @escaping (String) -> Void) {
                if islock {
                        let alertController = UIAlertController(title: "check password", message: nil, preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "ok", style: .default) { (action) in
                                let passwordTextField = alertController.textFields![0]
                                if passwordTextField.text?.count != 0 {
                                        completionHandler(passwordTextField.text!)
                                }
                        }
                        alertController.addAction(okAction)
                        
                        let cancelAction = UIAlertAction(title: "cancel", style: .destructive)  { (action) in
                        }
                        alertController.addAction(cancelAction)
                        
                        alertController.addTextField { (textField) in
                                textField.placeholder = "password"
                        }
                        
                        self.present(alertController, animated: true, completion: nil)
                }  else {
                        completionHandler(self.noPassword)
                }
        }
        
        override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
                let info = roomList[indexPath.row]
                let islock = info.password != noPassword
                promptIfNeedPassword(islock : islock) { (password) in
                        SocketManager.Manager.joinRoom(user: self.userName, roomID: info.roomID, password: password, completionHandler: { (success, content) in
                                if success {
                                        let updateInfo = RoomInfo.infoWith(data: content)
                                        let chatRoomVC = ChatRoomViewController(roomInfo: updateInfo)
                                        self.navigationController?.pushViewController(chatRoomVC, animated: true)
                                } else {
                                        // if join fail , content will contain error message
                                        let errorMessage = content["error"] as! String
                                        let alertController = UIAlertController(title: "error message", message: errorMessage, preferredStyle: .actionSheet)
                                        let okAction = UIAlertAction(title: "ok", style: .default, handler: nil)
                                        alertController.addAction(okAction)
                                        self.present(alertController, animated: true, completion: nil)
                                }
                        })
                }
        }
        
        override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
                return 50
        }
}


class ChatListCell : UITableViewCell {
        let nameLabel : UILabel = {
                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                return label
        }()
        
        let lockImageView : UIImageView = {
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
                self.addSubview(lockImageView)
                self.addSubview(nameLabel)
                
                NSLayoutConstraint.activate([
                        lockImageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                        lockImageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                        lockImageView.heightAnchor.constraint(equalToConstant: 20),
                        lockImageView.widthAnchor.constraint(equalToConstant: 20),
                        
                        nameLabel.topAnchor.constraint(equalTo: self.topAnchor),
                        nameLabel.leadingAnchor.constraint(equalTo: lockImageView.trailingAnchor, constant: 10),
                        nameLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                        nameLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                        nameLabel.heightAnchor.constraint(equalToConstant: self.frame.size.height)
                        ])
        }
}


