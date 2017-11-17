//
//  ChatRoomViewController.swift
//  SocketChatRoom
//
//  Created by 何家瑋 on 2017/10/27.
//  Copyright © 2017年 何家瑋. All rights reserved.
//

import UIKit

class ChatRoomViewController: UIViewController {

        // MARK: Chat property
        private var userName : String!
        private var userUUID : String!
        private var roomInfo : RoomInfo!
        private var messages = [MessageInfo]() {
                didSet {
                        DispatchQueue.main.async {
                                self.collectionView.reloadData()
                                self.scrollToBottom()
                        }
                }
        }
        
        // MARK: keyboard property
        private var defaultBottomConstant : CGFloat!
        private var currentLineNumber : CGFloat = 1.0
        private var containerViewBottomConstraint : NSLayoutConstraint!
        private var containerViewHeightConstraint : NSLayoutConstraint!
        
        // MARK: UI property
        private var showView : UIView?
        private var collectionView : UICollectionView = {
                let flowLayout = UICollectionViewFlowLayout()
                flowLayout.minimumLineSpacing = 20
                let view = UICollectionView(frame: CGRect.zero, collectionViewLayout: flowLayout)
                view.translatesAutoresizingMaskIntoConstraints = false
                view.contentInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                view.register(MessageCell.self, forCellWithReuseIdentifier: "id")
                view.backgroundColor = .white
                return view
        }()
        
        private var containerView : UIView = {
                let view = UIView()
                view.translatesAutoresizingMaskIntoConstraints = false
                view.backgroundColor = .white
                return view
        }()
        
        private var inputTextView : UITextView = {
                let textView = UITextView()
                textView.translatesAutoresizingMaskIntoConstraints = false
                textView.font = UIFont.systemFont(ofSize: 22)
                textView.layer.borderColor = UIColor(white: 0.5, alpha: 0.5).cgColor
                textView.layer.borderWidth = 1.0
                textView.layer.cornerRadius = 15
                return textView
        }()
        
        private var sendButton : UIButton = {
                let button = UIButton()
                button.setTitle("Send", for: .normal)
                button.setTitleColor(UIColor(red: 0, green: 137/255, blue: 249/255, alpha: 1), for: .normal)
                button.translatesAutoresizingMaskIntoConstraints = false
                button.addTarget(self, action: #selector(send(sender:)), for: .touchUpInside)
                return button
        }()
        
        init(roomInfo : RoomInfo) {
                super.init(nibName: nil, bundle: nil)
                self.roomInfo = roomInfo
        }
        
        required init?(coder aDecoder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidLoad() {
                super.viewDidLoad()
                view.backgroundColor = .white
                self.tabBarController?.tabBar.isHidden = true
                
                defaultBottomConstant = (view.safeAreaInsets.bottom == 0) ? -10 : 0
                
                view.addSubview(collectionView)
                view.addSubview(containerView)
                containerView.addSubview(inputTextView)
                containerView.addSubview(sendButton)
                
                collectionView.dataSource = self
                collectionView.delegate = self
                inputTextView.delegate = self
                
                setupAutoLayout()
                
                userName = UserDefaults.standard.string(forKey: "userName")
                userUUID = UserDefaults.standard.string(forKey: "userUUID")
        }
        
        override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                registKeyBoardNotification()
        }
        
        override func viewDidAppear(_ animated: Bool) {
                super.viewDidAppear(animated)
                SocketManager.Manager.receiveMessage { (messageInfo) in
                        self.messages.append(messageInfo)
                }
                
                SocketManager.Manager.chatUserDIdChange { (isJoin, user) in
                        if isJoin {
                                let notificationMSG = user + " is join the room"
                                self.showNotificationMessage(message: notificationMSG)
                        } else {
                                let notificationMSG = user + " is leave the room"
                                self.showNotificationMessage(message: notificationMSG)
                        }
                }
                
                SocketManager.Manager.chatRoomInfoDidChange { (info) in
                        self.roomInfo = info
                }
        }
        
        override func viewWillDisappear(_ animated: Bool) {
                super.viewWillDisappear(animated)
                removeKeyBoardNotification()
                SocketManager.Manager.leaveRoom(user: userName, roomID: roomInfo.roomID)
                
                // stop socket listen
                SocketManager.Manager.stopReceiveMessage()
                SocketManager.Manager.stopListenChatUserDIdChange()
                SocketManager.Manager.stopListenChatRoomInfo()
        }
        
        override func didReceiveMemoryWarning() {
                super.didReceiveMemoryWarning()
                // Dispose of any resources that can be recreated.
        }
        
        func setupAutoLayout() {
                containerViewBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: defaultBottomConstant)
                containerViewHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: 50)
                NSLayoutConstraint.activate([
                        /*  leadingAnchor -> left,  trailingAnchor -> right  */
                        collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                        collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                        collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                        
                        containerView.topAnchor.constraint(equalTo: collectionView.bottomAnchor),
                        containerViewHeightConstraint,
                        containerViewBottomConstraint,
                        containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                        containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                        
                        inputTextView.topAnchor.constraint(equalTo: containerView.topAnchor),
                        inputTextView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                        inputTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                        
                        sendButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                        sendButton.leadingAnchor.constraint(equalTo: inputTextView.trailingAnchor),
                        sendButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                        sendButton.heightAnchor.constraint(equalToConstant: 50),
                        sendButton.widthAnchor.constraint(equalToConstant: 60) ])
        }
        
        @objc func send(sender : UIButton) {
                inputTextView.resignFirstResponder()
                guard let text = inputTextView.text, !text.isEmpty else {
                        return
                }
                
                SocketManager.Manager.send(text: text, userID: userUUID, name: userName, roomID: roomInfo.roomID)
                
                // reset inputTextView
                currentLineNumber = 1.0
                inputTextView.text = ""
                containerViewHeightConstraint.constant = 50
        }
        
        private func showNotificationMessage(message : String) {
                if showView != nil {
                        showView?.removeFromSuperview()
                        showView = nil
                }
                
                let label = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width - 60, height: 30))
                label.text = message
                label.textAlignment = .center
                label.backgroundColor = .clear
                label.textColor = .white
                
                showView = UIView(frame: CGRect(x: 30, y: 0, width: label.frame.size.width, height: label.frame.size.height))
                showView?.backgroundColor = .lightGray
                showView?.alpha = 0.8
                showView?.addSubview(label)
                collectionView.addSubview(showView!)
                
                UIView.animate(withDuration: 0, delay: 0, options: .curveEaseInOut, animations: {
                        
                }) { (completed) in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
                                self.showView?.removeFromSuperview()
                                self.showView = nil
                        })
                }
        }
        
        func scrollToBottom() {
                if messages.count > 0 {
                        let index = IndexPath(item: messages.count - 1, section: 0)
                        collectionView.scrollToItem(at: index, at: .bottom, animated: true)
                }
        }
}

// MARK: - ViewController Helper
extension ChatRoomViewController {
        // MARK: keyboard
        func registKeyBoardNotification() {
                NotificationCenter.default.addObserver(self, selector: #selector(keyboardNotification(notification:)), name: .UIKeyboardWillHide, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(keyboardNotification(notification:)), name: .UIKeyboardWillShow, object: nil)
        }
        
        func removeKeyBoardNotification() {
                NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillHide, object: nil)
                NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillShow, object: nil)
        }
        
        @objc func keyboardNotification(notification : Notification) {
                if let keyboardFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                        containerViewBottomConstraint.constant = (notification.name == .UIKeyboardWillShow) ?view.safeAreaInsets.bottom - keyboardFrame.size.height - 10 : defaultBottomConstant
                        UIView.animate(withDuration: 0, delay: 0, options: .curveEaseOut, animations: {
                                self.view.layoutIfNeeded()
                        }, completion: { (completed) in
                                // scroll to bottom
                                self.scrollToBottom()
                        })
                }
        }
        
        // MARK: Calculate String Height
        func sizeOfString(_ string : String, size : CGSize) -> CGSize {
                let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
                let estimatedFrame = NSString(string: string).boundingRect(with: size, options: options, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 22)], context: nil)
                return estimatedFrame.size
        }
}

// MARK: - CollectionView Method
extension ChatRoomViewController : UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate {
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
                return messages.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "id", for: indexPath) as! MessageCell
                let info = messages[indexPath.row]
                if let message = info.message as? String {
                        let width = (collectionView.frame.size.width - 10) * 0.75
                        let height = CGFloat(MAXFLOAT)
                        let textSize = sizeOfString(message, size: CGSize(width: width, height: height))
                        cell.messageTextView.text = message
                        cell.messageTextView.backgroundColor = (info.senderID == userUUID) ? .blue : .lightGray
                        cell.messageTextView.textColor = (info.senderID == userUUID) ? .white : .black
                        cell.messageTextView.frame = (info.senderID == userUUID) ?
                                CGRect(x: cell.frame.size.width - textSize.width - 10, y: 0, width: textSize.width + 10, height: textSize.height + 20) :
                                CGRect(x: 0, y: 0, width: textSize.width + 10, height: textSize.height + 20)
                        cell.detailLabel.text = "send by " + info.senderName + " @ " + info.date
                        cell.detailLabel.textAlignment = (info.senderID == userUUID) ? .right : .left
                        cell.detailLabel.frame = CGRect(x: 0, y: textSize.height + 20, width: cell.frame.width, height: 30)
                }
                return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
                /*
                 If you do not implement this method, the flow layout uses the values in its itemSize property to set the size of items instead.
                 */
                let info = messages[indexPath.row]
                if let message = info.message as? String {
                        let width = (collectionView.frame.size.width - 10) * 0.75
                        let height = CGFloat(MAXFLOAT)
                        let textSize = sizeOfString(message, size: CGSize(width: width, height: height))
                        return CGSize(width: view.frame.width - 10, height: textSize.height + 20 + 30)
                } else {
                        // for temp, maybe some day will support image
                        return CGSize.zero
                }
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
                inputTextView.resignFirstResponder()
        }
}

// MARK: - UITextViewDelegate
extension ChatRoomViewController : UITextViewDelegate {
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
                
                let ascii = text.cString(using: String.Encoding.utf8)!.first!
                switch ascii {
                case Int8(0):
                        print("press backspace")
                case Int8(10):
                        print("press return")
                default: break
                }

                return true
        }
        
        func textViewDidChange(_ textView: UITextView) {
                let numberOfLine = CGFloat(Int((textView.contentSize.height - 16) / textView.font!.lineHeight))
                if currentLineNumber < 3, numberOfLine > currentLineNumber {
                        containerViewHeightConstraint.constant += textView.font!.lineHeight
                } else if currentLineNumber < 4, numberOfLine < currentLineNumber {
                        containerViewHeightConstraint.constant -= textView.font!.lineHeight
                }
                
                currentLineNumber = numberOfLine
        }
}

// MARK: - CollectionViewCell
class MessageCell : UICollectionViewCell {
        let messageTextView : UITextView = {
                let textView = UITextView()
                textView.isScrollEnabled = false
                textView.isEditable = false
                textView.font = UIFont.systemFont(ofSize: 22)
                textView.layer.borderColor = UIColor(white: 0.5, alpha: 0.5).cgColor
                textView.layer.borderWidth = 1.0
                textView.layer.cornerRadius = 15
                return textView
        }()
        
        let detailLabel : UILabel = {
                let label = UILabel()
                label.font = UIFont.systemFont(ofSize: 15)
                return label
        }()
        
        required init?(coder aDecoder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
        }
        
        override init(frame: CGRect) {
                super.init(frame: frame)
                setupCell()
        }
        
        private func setupCell() {
                self.addSubview(messageTextView)
                self.addSubview(detailLabel)
        }
}

