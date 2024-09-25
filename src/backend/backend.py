from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit, join_room, leave_room
from util import ChatServer
import util

app = Flask(__name__)
app.config["ENV"] = "production"
app.config["DEBUG"] = False
app.config["SECRET_KEY"] = "your_secret_key"
socketio = SocketIO(
    app, cors_allowed_origins=["http://localhost:5001", "http://127.0.0.1:5001"]
)
chat_server = ChatServer()


@app.route("/")
def index():
    return "WebSocket server running!"

@app.route("/check_username", methods=["POST"])
def check_username():
    data = request.get_json()
    username = data.get("username")
    user = chat_server.get_user(username)
    if user:
        return jsonify({"available": False}), 200
    return jsonify({"available": True}), 200

@app.route("/verify_room_access", methods=["POST"])
def verify_room_access():
    data = request.get_json()
    room_id = data.get("room_id")
    username = data.get("username")
    chatroom = chat_server.chatrooms.get(room_id)
    if chatroom and chatroom.is_user_authorized(username):
        return jsonify({"authorized": True}), 200
    else:
        return jsonify({"authorized": False}), 200

@socketio.on("join_lobby")
def handle_join_lobby(data):
    username = data.get("username")
    if not username:
        return False  # Reject the connection
    user = chat_server.get_user(username)
    if not user:
        chat_server.add_user(username)
    join_room(username)
    emit("update_user_list", chat_server.list_users_in_lobby(), broadcast=True)

@socketio.on("chat_request")
def handle_chat_re_quest(data):
    from_username = data.get("from_user")
    to_username = data.get("to_user")

    from_user = chat_server.get_user(from_username)
    to_user = chat_server.get_user(to_username)

    if not from_user or not to_user:
        return

    # prevent multiple pending requests from the same user
    if from_user.username in chat_server.pending_requests:
        emit(
            "chat_response",
            {"accepted": False, "message": "You already have a pending chat request"},
            room=from_user.username
        )
        return

    if not to_user.in_room:
        chat_server.add_pending_request(from_user, to_user)
        emit("chat_request", {"from_user": from_user.username}, room=to_user.username)
    else:
        emit(
            "chat_response",
            {"accepted": False, "message": "User not available"},
            room=from_user.username
        )

@socketio.on("chat_response")
def handle_chat_response(data):
    from_username = data.get("to_user")
    to_username = data.get("from_user")  # the user who sent the request
    accepted = data.get("accepted")

    if not from_username or not to_username:
        return

    from_user = chat_server.get_user(from_username)
    to_user = chat_server.get_user(to_username)

    if to_user and from_user:
        pending_request = chat_server.get_pending_request(to_user.username)
        if pending_request and pending_request.to_user == from_user:
            chat_server.remove_pending_request(to_user.username)
            if accepted:
                room = chat_server.create_room(to_user, from_user)
                emit(
                    "chat_response",
                    {
                        "accepted": True,
                        "room_id": room.id,
                        "other_user": from_user.username
                    },
                    room=to_user.username
                )
                emit(
                    "chat_response",
                    {
                        "accepted": True,
                        "room_id": room.id,
                        "other_user": to_user.username
                    },
                    room=from_user.username
                )
            else:
                # notify the requesting user that the request was declined
                emit(
                    "chat_response",
                    {"accepted": False, "message": "Chat request declined"},
                    room=to_user.username
                )
        else:
            emit(
                "chat_response",
                {"accepted": False, "message": "No pending chat request found"},
                room=from_user.username
            )

@socketio.on("join_room")
def handle_join_room(data):
    username = data.get("username")
    room_id = data.get("room_id")
    user = chat_server.get_user(username)
    if util.user_authorized_in_room(username, room_id, chat_server):
        user.in_room = True
        join_room(room_id)
        emit("join_room_success", {"message": "Joined room successfully"})
        emit("update_user_list", chat_server.list_users_in_lobby(), broadcast=True)
    else:
        emit("join_room_failure", {"message": "Unauthorized access"})

@socketio.on("leave_room")
def handle_leave_room(data):
    username = data.get("username")
    room_id = data.get("room_id")
    user = chat_server.get_user(username)
    if util.user_authorized_in_room(username, room_id, chat_server):
        emit(
            "receive_message",
            {"message": "has left the chat", "username": username, "type": "system"},
            room=room_id,
            include_self=False
        )
        user.in_room = False
        leave_room(room_id)
        emit("update_user_list", chat_server.list_users_in_lobby(), broadcast=True)

@socketio.on("send_message")
def handle_send_message(data):
    room_id = data.get("room_id")
    aes_key = data.get("aes_key")
    iv = data.get("iv")
    message = data.get("message")
    username = data.get("username")
    if util.user_authorized_in_room(username, room_id, chat_server):
        emit(
            "receive_message",
            {
                "aes_key": aes_key,
                "iv": iv,
                "message": message,
                "username": username,
                "type": "user",
            },
            room=room_id,
            include_self=False
        )
    else:
        emit("error", {"message": "Unauthorized"})

@socketio.on("share_public_key")
def handle_share_public_key(data):
    room_id = data.get("room_id")
    public_key = data.get("public_key")
    if room_id and public_key:
        emit(
            "receive_public_key",
            {"public_key": public_key},
            room=room_id,
            include_self=False,
        )

@socketio.on("leave_server")
def handle_leave_server(data):
    username = data.get("username")
    user = chat_server.get_user(username)
    if user:
        chat_server.remove_user(username)
        emit("update_user_list", chat_server.list_users_in_lobby(), broadcast=True)


if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5002)
