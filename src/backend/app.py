from gevent import monkey

# ugly, but required, see for more:
# https://flask-socketio.readthedocs.io/en/latest/deployment.html#using-multiple-workers
monkey.patch_all()

import os
import logging
import sys

from chat_manager import RedisChatManager
from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit, join_room, leave_room

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s][%(name)s][%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config["ENV"] = os.environ["FLASK_ENV"]
app.config["DEBUG"] = os.environ["FLASK_DEBUG"]
app.config["SECRET_KEY"] = os.environ["FLASK_SECRET_KEY"]

# alb_dbs = os.environ["ALB_DNS"]
alb_dns = "http://k8s-default-livechat-c766082308-918824972.eu-north-1.elb.amazonaws.com"
redis_host = os.environ["REDIS_HOST"]
redis_port = os.environ["REDIS_PORT"]
socketio = SocketIO(
    app,
    cors_allowed_origins=[alb_dns],
    message_queue=f"redis://{redis_host}:{redis_port}/0",
    logger=True,
    engineio_logger=True
)
manager = RedisChatManager(host=redis_host, port=redis_port, db=1)


@app.route("/api/")
def index():
    return "WebSocket server running!"

@app.route("/api/container_id", methods=["GET"])
def container_id():
    # TODO remove after not necessary
    import socket
    container_id = socket.gethostname()
    return jsonify({"container_id": container_id}), 200

@app.route("/api/check_username", methods=["POST"])
def check_username():
    data = request.get_json()
    username = data.get("username")
    user = manager.get_user(username)
    if user:
        return jsonify({"available": False}), 200
    return jsonify({"available": True}), 200

@app.route("/api/verify_room_access", methods=["POST"])
def verify_room_access():
    data = request.get_json()
    room_id = data.get("room_id")
    username = data.get("username")
    if manager.user_authorized_in_room(username, room_id):
        return jsonify({"authorized": True}), 200
    else:
        logger.warning(f"Failed room verification to room '{room_id}' by {username}")
        return jsonify({"authorized": False}), 200    

@socketio.on("join_lobby")
def handle_join_lobby(data):
    username = data.get("username")
    if not username:
        return False  # Reject the connection
    user = manager.get_user(username)
    if not user:
        logger.info(f"Adding new user '{username}'")
        manager.add_user(username)
    join_room(username)
    emit("update_user_list", manager.list_users_in_lobby(), broadcast=True)

@socketio.on("chat_request")
def handle_chat_request(data):
    from_username = data.get("from_user")
    to_username = data.get("to_user")

    from_user = manager.get_user(from_username)
    to_user = manager.get_user(to_username)

    if not from_user:
        logger.warning(f"Could not find from_user '{from_user}'")
        return

    if not to_user:
        logger.warning(f"Could not find to_user '{from_user}'")
        return

    # prevent multiple pending requests from the same user
    if manager.get_pending_request(from_username):
        logger.warning(
            f"User '{from_username}' attempted to request '{to_username}' to chat "
            "while having a pending chat request"
        )
        emit(
            "chat_response",
            {"accepted": False, "message": "You already have a pending chat request"},
            room=from_username
        )
        return

    if not to_user["in_room"]:
        manager.add_pending_request(from_username, to_username)
        emit("chat_request", {"from_user": from_username}, room=to_username)
    else:
        emit(
            "chat_response",
            {"accepted": False, "message": "User not available"},
            room=from_username
        )

@socketio.on("chat_response")
def handle_chat_response(data):
    from_username = data.get("to_user")
    to_username = data.get("from_user")  # the user who sent the request
    accepted = data.get("accepted")

    if not from_username or not to_username:
        return

    from_user = manager.get_user(from_username)
    to_user = manager.get_user(to_username)

    if to_user and from_user:
        pending_request = manager.get_pending_request(to_username)
        if pending_request and pending_request["to_username"] == from_username:
            manager.remove_pending_request(to_username)
            if accepted:
                chatroom = manager.create_chatroom(to_user, from_user)
                emit(
                    "chat_response",
                    {
                        "accepted": True,
                        "room_id": chatroom["id"],
                        "other_user": from_username
                    },
                    room=to_username
                )
                emit(
                    "chat_response",
                    {
                        "accepted": True,
                        "room_id": chatroom["id"],
                        "other_user": to_username
                    },
                    room=from_username
                )
            else:
                # notify the requesting user that the request was declined
                emit(
                    "chat_response",
                    {"accepted": False, "message": "Chat request declined"},
                    room=to_username
                )
        else:
            emit(
                "chat_response",
                {"accepted": False, "message": "No pending chat request found"},
                room=from_username
            )

@socketio.on("join_room")
def handle_join_room(data):
    username = data.get("username")
    room_id = data.get("room_id")
    if manager.user_authorized_in_room(username, room_id):
        join_room(room_id)
        emit("join_room_success", {"message": "Joined room successfully"})
        emit("update_user_list", manager.list_users_in_lobby(), broadcast=True)
    else:
        logger.warning(f"Unauthorized attempt to join room '{room_id}' by {username}")
        emit("join_room_failure", {"message": "Unauthorized access"})

@socketio.on("leave_room", namespace="/socket.io")
def handle_leave_room(data):
    username = data.get("username")
    room_id = data.get("room_id")
    if manager.user_authorized_in_room(username, room_id):
        emit(
            "receive_message",
            {"message": "has left the chat", "username": username, "type": "system"},
            room=room_id,
            include_self=False
        )
        leave_room(room_id)
        manager.leave_chatroom(username, room_id)
        emit("update_user_list", manager.list_users_in_lobby(), broadcast=True)

@socketio.on("send_message")
def handle_send_message(data):
    room_id = data.get("room_id")
    aes_key = data.get("aes_key")
    iv = data.get("iv")
    message = data.get("message")
    username = data.get("username")
    if manager.user_authorized_in_room(username, room_id):
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
    user = manager.get_user(username)
    if user:
        manager.remove_user(username)
        emit("update_user_list", manager.list_users_in_lobby(), broadcast=True)


if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5000)
