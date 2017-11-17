
var app = require("express")();
var http = require("http").Server(app);
var io = require("socket.io")(http);

var userList = [];
var roomList = [];

app.get("/", function(req, res){
  res.send("<h1>SocketChat Server</h1>");
});


http.listen(3000, function(){
  console.log("Listening on *:3000");

  // public room
  var roomID = uuid();
  var roomInfo = {};
  var roomUser = [];
  roomInfo["roomUser"] = roomUser;
  roomInfo["roomName"] = "public Room";
  roomInfo["password"] = "None";
  roomInfo["roomID"] = roomID;
  roomList.push(roomInfo);
});

function uuid() {
  var d = Date.now();
  if (typeof performance !== "undefined" && typeof performance.now === "function"){
    d += performance.now(); //use high-precision timer if available
  }
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
    var r = (d + Math.random() * 16) % 16 | 0;
    d = Math.floor(d / 16);
      return (c === "x" ? r : (r & 0x3 | 0x8)).toString(16);
  });
};

io.on("connection", function(clientSocket){

// User Event
  clientSocket.on("connectUser", function(clientNickname, userID) {
      console.log(clientNickname+ "(" + userID +")" + " was connected.");

      var userInfo = {};
      var foundUser = false;
      for (var i=0; i<userList.length; i++) {
        if (userList[i]["userID"] == userID) {
          userList[i]["nickname"] = clientNickname;
          userList[i]["isConnected"] = true;
          userList[i]["socketID"] = clientSocket.id;
          userInfo = userList[i];
          foundUser = true;
          break;
        }
      }

      if (!foundUser) {
        userInfo["userID"] = userID;
        userInfo["socketID"] = clientSocket.id;
        userInfo["nickname"] = clientNickname;
        userInfo["isConnected"] = true
        userList.push(userInfo);
      }

      io.emit("userList", userList);
      io.emit("userConnectUpdate", userInfo);
  });

  clientSocket.on("disconnect", function(){
    console.log("a user disconnected");

    var clientNickname;
    var UserID;
    for (var i = 0; i < userList.length; i++) {
      if (userList[i]["socketID"] == clientSocket.id) {
        userList[i]["isConnected"] = false;
        UserID = userList[i]["userID"];
        clientNickname = userList[i]["nickname"];
        break;
      }
    }

    for (var i = 0; i < roomList.length; i++) {
      var roomInfo = roomList[i];
      var users = roomInfo["roomUser"]
      for (var j = 0; j < users.length; j++) {
        var userInfo = users[j];
        if (userInfo["socketID"] == clientSocket.id) {
          roomInfo["roomUser"].splice(j, 1);

          clientSocket.to(roomInfo["roomID"]).emit("roomInfoDIdChange", roomInfo);
          clientSocket.leave(roomInfo["roomID"]);
        }
      }
    }

    io.emit("userList", userList);
    io.emit("roomList", roomList);
  });

  clientSocket.on("exitUser", function(clientNickname){
    for (var i=0; i<userList.length; i++) {
      if (userList[i]["socketID"] == clientSocket.id) {
        userList.splice(i, 1);
        break;
      }
    }
    io.emit("userExitUpdate", clientNickname);
  });

  clientSocket.on("requestUserList", function() {
    clientSocket.emit("userList", userList);
  });


  // clientSocket.on("broadcastMessage", function(clientNickname, message){
  //   console.log("receive message from " + clientNickname);
  //   var currentDateTime = new Date().toLocaleString();
  //   var messageInfo = {};
  //   messageInfo["senderName"] = clientNickname;
  //   messageInfo["message"] = message;
  //   messageInfo["date"] = currentDateTime;
  //
  //   delete typingUsers[clientNickname];
  //   // io.emit is send message to group
  //   io.emit("userTypingUpdate", typingUsers);
  //   io.emit("newBroadcastMessage", messageInfo);
  //   //io.emit("newChatMessage", clientNickname, message, currentDateTime);
  //   // clientSocket.broadcast.to().emit("newChatMessage", messageInfo);
  // });

// Message Event
  clientSocket.on("chatMessage", function(clientNickname, userID, message, roomID){
    console.log("receive message from " + clientNickname + " to " + roomID);
    var currentDateTime = new Date().toLocaleString();
    var messageInfo = {};
    messageInfo["senderName"] = clientNickname;
    messageInfo["senderID"] = userID;
    messageInfo["message"] = message;
    messageInfo["date"] = currentDateTime;

    // send to all client in roomID
    io.in(roomID).emit("newChatMessage", messageInfo);
  });


// Room Event
  clientSocket.on("createRoom", function(clientNickname, roomName, password){
    var roomID = uuid();
    var roomInfo = {};

    for (var i = 0; i < userList.length; i++) {
      var userInfo = userList[i];
      if (userInfo["socketID"] == clientSocket.id) {
        roomInfo["roomUser"] = [userInfo];
      }
    }

    roomInfo["roomName"] = roomName;
    roomInfo["password"] = password;
    roomInfo["roomID"] = roomID;
    roomList.push(roomInfo);

    // update room list to all client
    io.emit("roomList", roomList);

    clientSocket.join(roomID);
    clientSocket.emit("roomActionResponse", true, roomInfo);
  });

  clientSocket.on("requestRoomList", function() {
    clientSocket.emit("roomList", roomList);
  });

  clientSocket.on("askForJoinRoom", function(clientNickname, roomID, password) {
    console.log(clientNickname + " ask join Room : " + roomID);
    for(var i = 0; i < roomList.length; i++) {
      var roomInfo = roomList[i];
      if (roomInfo["roomID"] == roomID) {
        if (roomInfo["password"] == password) {

          // get userInfo from userList
          for (var i = 0; i < userList.length; i++) {
            var userInfo = userList[i];
            if (userInfo["socketID"] == clientSocket.id) {
              roomInfo["roomUser"].push(userInfo);
              clientSocket.join(roomID);

              // sending the latest info to the sender
              clientSocket.emit("roomActionResponse", true, roomInfo);

              // sending to all clients in roomID room except sender
              clientSocket.to(roomID).emit("usersDIdChange", true, clientNickname);

              clientSocket.to(roomID).emit("roomInfoDIdChange", roomInfo);

              // update room list to all client
              io.emit("roomList", roomList);
              break;
            } // end of if(userInfo["socketID"] == clientSocket.id)
          } // end of userList for loop

          break;
        } else {
          console.log("wrong password");
          var errMSG = {"error" : "wrong password"};
          clientSocket.emit("roomActionResponse", false, errMSG);
          break;
        }
      } // end of if(roomInfo["roomID"] == roomID)
    } // end of roomList for loop
  });

  clientSocket.on("leaveRoom", function(clientNickname, roomID) {
    console.log(clientNickname + " is leaving Room : " + roomID);

    for(var i = 0; i < roomList.length; i++) {
      var roomInfo = roomList[i];

      for (var j = 0; j < roomInfo["roomUser"].length; j++) {
        var userInfo = roomInfo["roomUser"][j];
        if (userInfo["socketID"] == clientSocket.id) {
          roomInfo["roomUser"].splice(j, 1);

          // update chat room info
          clientSocket.to(roomID).emit("usersDIdChange", false, clientNickname);

          clientSocket.to(roomID).emit("roomInfoDIdChange", roomInfo);

          clientSocket.leave(roomID);

          // update room list to all client
          io.emit("roomList", roomList);
          break;
        } // end of if(userInfo["socketID"] == clientSocket.id)
      }
    } // end of roomList for loop
  });


// Status Event
  clientSocket.on("startType", function(clientNickname){
    console.log("User " + clientNickname + " is writing a message...");
    // io.emit("userTypingUpdate", typingUsers);
  });

  clientSocket.on("stopType", function(clientNickname){
    console.log("User " + clientNickname + " has stopped writing a message...");
    // io.emit("userTypingUpdate", typingUsers);
  });

});
