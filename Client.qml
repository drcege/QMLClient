import QtQuick 2.4
import QtQuick.Controls 1.3
import QtQuick.Window 2.2
import Qt.WebSockets 1.0
import QtQuick.Layouts 1.1
import QtQuick.Controls.Styles 1.3

Window {
    id: client
    title: qsTr("Client")
    width: 400
    height: 520
    visible: true

    property string clientID: "xxx"
    property var fanSpeed : ["low", "medium", "high"]
    property var tempMax
    property var tempMin
    property var tBefore
    property var tAfter
    property bool working

    function testInterval() {
        tAfter = Date.now();
        if(tAfter - tBefore > 1000) {
            var setReq = {
            "method": "set",
            "cid": clientID,
            "target": destTemp.text,
            "speed": exFan.current.text
            }
            socket.sendTextMessage(JSON.stringify(setReq));
            console.log("Send: "+ setReq);
        }
        tBefore = tAfter;
    }

    WebSocket {
        id: socket
        //url: "ws://echo.websocket.org"
        url: "ws://localhost:8888/"

        onTextMessageReceived: {
            textLog.append("Received: " + message);
            var msg = JSON.parse(message);

            switch(msg.method){
            case "handshake":
                if(msg.result === "ok") {
                    if(msg.config.mode === "winter")
                        mode.text = qsTr("制热");
                    else if(msg.config.mode === "summer")
                        mode.text = qsTr("制冷");
                    tempMax = msg.config.temp-max;
                    tempMin = msg.config.temp-min;
                }
                break;
            case "get":
                if(msg.result === "ok")
                    curTemp.text = msg.temp
                break;
            case "standby":
                if(msg.cid === clientID) {
                    working = false;
                    repeatTimer.stop();
                }
                break;
            case "shutdown": case "checkout":
                if(msg.result === "ok")
                    socket.active = false;
                else
                    radioOff.checked = true;
                break;
            }
        }
        onStatusChanged:{
            if (socket.status == WebSocket.Open) {
                textLog.append("Socket open");

                var handshake = {
                    "method" : "handshake",
                    "cid" : clientID,
                    "temp" : curTemp.text,
                    "speed" : fanSpeed[1],
                    "target" : destTemp.text
                }

                socket.sendTextMessage(JSON.stringify(handshake));
                console.log("Send: "+ handshake);
            } else if(socket.status == WebSocket.Connecting) {
                textLog.append("Connecting...");
            } else {
                if (socket.status == WebSocket.Error) {
                    socket.active = false
                    textLog.append("Error: " + socket.errorString);
                } else if (socket.status == WebSocket.Closed) {
                    textLog.append("Socket closed");
                }
                radioOff.checked = true
            }
        }
        active: false
    }

    GroupBox {
        id: groupSwitch
        x: 270
        width: 80
        height: 80
        anchors.top: groupFan.bottom
        anchors.topMargin: 30
        anchors.right: parent.right
        anchors.rightMargin: 50
        title: qsTr("开关")

        ColumnLayout {
            anchors.fill: parent

            ExclusiveGroup { id: onoff }
            RadioButton {
                id: radioOn
                text: qsTr("On")
                exclusiveGroup: onoff
                onClicked: socket.active = true
            }

            RadioButton {
                id: radioOff
                text: qsTr("Off")
                exclusiveGroup: onoff
                checked: true
                onClicked: {
                    var shutdown = {
                        method: "shutdown",
                        cid: clientID
                    }
                    socket.sendTextMessage(JSON.stringify(shutdown));
                }
            }
        }
    }

    GroupBox {
        id: groupTemp
        width: 180
        height: 80
        anchors.top: groupFan.bottom
        anchors.topMargin: 30
        anchors.left: parent.left
        anchors.leftMargin: 50
        title: qsTr("温度调节")

        RowLayout {
            anchors.fill: parent

            Button {
                id: tempUp
                text: qsTr("+")
                checkable: false
                onClicked: {
                    destTemp.text = (parseInt(destTemp.text) + 1).toString();
                    testInterval();
                }
            }

            Button {
                id: tempDown
                text: qsTr("-")
                onClicked: {
                    destTemp.text = (parseInt(destTemp.text) - 1).toString();
                    testInterval();
                }
            }
        }
    }

    GroupBox {
        id: groupFan
        x: 270
        title: qsTr("风速调节")
        width: 80
        height: 140
        anchors.top: parent.top
        anchors.topMargin: 60
        anchors.right: parent.right
        anchors.rightMargin: 50

        ColumnLayout {
            anchors.fill: parent

            ExclusiveGroup {
                id: exFan
                onCurrentChanged: {
                    testInterval();
                }
            }
            RadioButton {
                id: radioHigh
                text: qsTr("高")
                exclusiveGroup: exFan
            }
            RadioButton {
                id: radioMed
                text: qsTr("中")
                checked: true
                exclusiveGroup: exFan
            }

            RadioButton {
                id: radioLow
                text: qsTr("低")
                exclusiveGroup: exFan
            }
        }
    }

    GroupBox {
        id: groupCur
        width: 80
        height: 60
        anchors.top: parent.top
        anchors.topMargin: 60
        anchors.left: parent.left
        anchors.leftMargin: 50
        title: qsTr("当前温度")

        RowLayout {
            anchors.fill: parent

            Label {
                id: curTemp
                text: qsTr("25")
                font.pointSize: 12
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
            }

            Label {
                id: label1
                text: qsTr("℃")
                font.pointSize: 12
                anchors.leftMargin: 47
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
            }
        }
    }

    GroupBox {
        id: groupDest
        width: 80
        height: 60
        anchors.left: parent.left
        anchors.leftMargin: 150
        anchors.top: parent.top
        anchors.topMargin: 60
        title: qsTr("目标温度")

        RowLayout {
            anchors.fill: parent

            Label {
                id: destTemp
                text: qsTr("25")
                font.pointSize: 12
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
            }

            Label {
                id: label2
                text: qsTr("℃")
                font.pointSize: 12
                anchors.leftMargin: 53
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
            }
        }
    }

    GroupBox {
        id: groupFee
        width: 80
        height: 60
        anchors.top: groupCur.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 50
        title: qsTr("费用")

        RowLayout {
            anchors.fill: parent

            Label {
                id: fee
                text: qsTr("￥")
                font.pointSize: 12
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
            }

            Label {
                id: label3
                text: qsTr("0.0")
                font.pointSize: 12
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
            }
        }
    }

    GroupBox {
        id: groupMode
        width: 80
        height: 60
        anchors.left: parent.left
        anchors.leftMargin: 150
        anchors.top: groupDest.bottom
        anchors.topMargin: 20
        title: qsTr("工作模式")

        Label {
            id: mode
            text: qsTr("制冷")
            font.pointSize: 12
            verticalAlignment: Text.AlignVCenter
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
        }
    }

    GroupBox {
        id: groupLog
        anchors.right: parent.right
        anchors.rightMargin: 50
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        anchors.top: groupTemp.bottom
        anchors.topMargin: 30
        title: qsTr("状态")

        TextArea {
            id: textLog
            text: "Welcome！"
            anchors.fill: parent
            readOnly: true
            selectByKeyboard: true
            wrapMode: TextEdit.Wrap
        }
    }

    BusyIndicator {
        z: 1
        anchors.fill: parent
        anchors.margins: 60
        running: socket.status == WebSocket.Connecting || socket.status == WebSocket.Closing
    }

    Timer {
        id: repeatTimer
        interval: 1000
        repeat: true
        onTriggered: {
            var getReq = {
                "method": "get",
                "cid": clientID
                }
            socket.sendTextMessage(JSON.stringify(getReq));
            console.log("Send: " + getReq);
        }
    }

    Timer {
        //id:
    }

    Component.onCompleted: {
        tBefore = Date.now();
        console.log(tBefore);
    }
}
