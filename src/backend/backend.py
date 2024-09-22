from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit, disconnect, join_room, leave_room


from util import ChatServer

app = Flask(__name__)
app.config["SECRET_KEY"] = "your_secret_key"
socketio = SocketIO(
    app, cors_allowed_origins=["http://localhost:5001", "http://127.0.0.1:5001"]
)
chat_server = ChatServer()


@app.route("/")
def index():
    return "WebSocket server running!"

# Check username availability
@app.route("/check_username", methods=["POST"])
def check_username():
    data = request.get_json()
    username = data.get("username")
    if chat_server.get_user_by_username(username):
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

@socketio.on("connect")
def handle_connect():
    # update sid every time a new connection is made
    username = request.args.get("username")
    if not username:
        return False  # Reject the connection
    user = chat_server.get_user_by_username(username)
    if user:
        chat_server.update_user_sid(user, request.sid)

# @socketio.on("disconnect")
# def handle_disconnect():
#     if chat_server.user_is_connected(request.sid):
#         chat_server.remove_user(request.sid)
#         emit("update_user_list", chat_server.list_users_in_lobby(), broadcast=True)
#     pass

@socketio.on("join_lobby")
def handle_join_lobby(data):
    username = data.get("username")
    if not username:
        return False  # Reject the connection
    user = chat_server.get_user_by_username(username)
    if not user:
        chat_server.add_user(request.sid, username)
    emit("update_user_list", chat_server.list_users_in_lobby(), broadcast=True)

# Handle chat request
@socketio.on("chat_request")
def handle_chat_request(data):
    from_user = chat_server.get_user_by_sid(request.sid)
    to_username = data.get("to_user")

    if not from_user or not to_username:
        return

    # Prevent multiple pending requests from the same user
    if from_user.sid in chat_server.pending_requests:
        emit(
            "chat_response",
            {"accepted": False, "message": "You already have a pending chat request"},
            room=from_user.sid
        )
        return

    to_user = chat_server.get_user_by_username(to_username)
    if to_user and not to_user.in_room:
        # Add pending request
        chat_server.add_pending_request(from_user, to_user)
        # Send chat request to recipient
        emit("chat_request", {"from_user": from_user.username}, room=to_user.sid)
    else:
        emit(
            "chat_response",
            {"accepted": False, "message": "User not available"},
            room=from_user.sid
        )

# Handle chat response
@socketio.on("chat_response")
def handle_chat_response(data):
    from_sid = request.sid
    from_user = chat_server.get_user_by_sid(from_sid)
    to_username = data.get("from_user")  # The user who sent the request
    accepted = data.get("accepted")

    if not from_user or not to_username:
        return

    # Find the requesting user
    to_user = chat_server.get_user_by_username(to_username)

    if to_user:
        pending_request = chat_server.get_pending_request(to_user.sid)
        if pending_request and pending_request.to_user == from_user:
            # Remove pending request
            chat_server.remove_pending_request(to_user.sid)
            if accepted:
                # Create a chat room
                room = chat_server.create_room(to_user, from_user)
                for user in [to_user, from_user]:
                    emit(
                        "chat_response",
                        {"accepted": True, "room_id": room.id},
                        room=user.sid
                    )
            else:
                # Notify the requesting user that the request was declined
                emit(
                    "chat_response",
                    {"accepted": False, "message": "Chat request declined"},
                    room=to_user.sid
                )
        else:
            emit(
                "chat_response",
                {"accepted": False, "message": "No pending chat request found"},
                room=from_user.sid
            )

@socketio.on("join_room")
def handle_join_room(data):
    username = data.get("username")
    room_id = data.get("room_id")
    user = chat_server.get_user_by_sid(request.sid)
    chatroom = chat_server.chatrooms.get(room_id)

    if user and chatroom and chatroom.is_user_authorized(username):
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
    user = chat_server.get_user_by_sid(request.sid)
    chatroom = chat_server.chatrooms.get(room_id)

    if user and chatroom and chatroom.is_user_authorized(username):
        emit(
            "receive_message",
            {"message": "has left the chat", "username": username},
            room=room_id
        )
        user.in_room = False
        leave_room(room_id)
        emit("update_user_list", chat_server.list_users_in_lobby(), broadcast=True)

@socketio.on("send_message")
def handle_send_message(data):
    room_id = data.get("room_id")
    message = data.get("message")
    username = data.get("username")
    user = chat_server.get_user_by_sid(request.sid)
    chatroom = chat_server.chatrooms.get(room_id)

    if user and chatroom and chatroom.is_user_authorized(username):
        emit(
            "receive_message", {"message": message, "username": username}, room=room_id
        )
    else:
        emit("error", {"message": "Unauthorized"})

# @socketio.on("disconnect")
# def handle_disconnect():
#     user = chat_server.get_user_by_sid(request.sid)
#     if user:
#         for room_id in chat_server.chatrooms.keys():
#             leave_room(room_id)
#         chat_server.remove_user(user.sid)
#         emit("update_user_list", chat_server.list_usernames(), broadcast=True)


# @socketio.on("leave_lobby")
# def handle_leave_lobby(data):
#     username = data.get("username")
#     user = chat_server.get_user_by_sid(request.sid)
#     if user and user.username == username:
#         chat_server.remove_user(user.sid)
#         emit("update_user_list", chat_server.list_users_in_lobby(), broadcast=True)


if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5002)
