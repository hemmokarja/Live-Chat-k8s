from gevent import monkey

# ugly, but required, see for more:
# https://flask-socketio.readthedocs.io/en/latest/deployment.html#using-multiple-workers
monkey.patch_all()

import os
import logging
import sys

from flask import jsonify, request
from flask_socketio import emit, join_room, leave_room

import initialization

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s][%(name)s][%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

app = initialization.init_app()
socketio = initialization.init_socket(app)
manager = initialization.init_chat_manager()


@app.route("/api/")
def index():
    logger.info("Index endpoint hit")
    return "WebSocket server running!"

@app.route("/api/check_username", methods=["POST"])
def check_username():
    data = request.get_json()
    username = data.get("username")
    logger.info(f"Checking availability for username: {username}")
    user = manager.get_user(username)
    if user:
        logger.info(f"Username '{username}' is already taken")
        return jsonify({"available": False}), 200
    logger.info(f"Username '{username}' is available")
    return jsonify({"available": True}), 200

@app.route("/api/verify_room_access", methods=["POST"])
def verify_room_access():
    data = request.get_json()
    room_id = data.get("room_id")
    username = data.get("username")
    logger.info(f"Verifying room access for username: {username} in room: {room_id}")
    if manager.user_authorized_in_room(username, room_id):
        logger.info(f"Access granted for user '{username}' to room '{room_id}'")
        return jsonify({"authorized": True}), 200
    else:
        logger.warning(f"Access denied for user '{username}' to room '{room_id}'")
        return jsonify({"authorized": False}), 200    

@socketio.on("join_lobby")
def handle_join_lobby(data):
    username = data.get("username")
    if not username:
        logger.warning("Attempt to join lobby without a username")
        return False  # reject the connection
    user = manager.get_user(username)
    if not user:
        logger.info(f"Adding new user '{username}' to the server")
        manager.add_user(username)
    join_room(username)
    logger.info(f"User '{username}' joined the lobby")
    emit("update_user_list", manager.list_users_in_lobby(), broadcast=True)

@socketio.on("chat_request")
def handle_chat_request(data):
    from_username = data.get("from_user")
    to_username = data.get("to_user")

    logger.info(f"User '{from_username}' requested chat with '{to_username}'")

    from_user = manager.get_user(from_username)
    to_user = manager.get_user(to_username)

    if not from_user:
        logger.error(f"Could not find from_user '{from_username}'")
        return

    if not to_user:
        logger.error(f"Could not find to_user '{to_username}'")
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
        logger.info(f"User '{to_username}' is not in a room, pending request added")
        manager.add_pending_request(from_username, to_username)
        emit("chat_request", {"from_user": from_username}, room=to_username)
    else:
        logger.info(f"User '{to_username}' is already in a room, request denied")
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
        logger.error("Missing username in chat response")
        return

    logger.info(
        f"Chat response from '{from_username}' to '{to_username}': "
        f"{'accepted' if accepted else 'declined'}"
    )

    from_user = manager.get_user(from_username)
    to_user = manager.get_user(to_username)

    if to_user and from_user:
        pending_request = manager.get_pending_request(to_username)
        if pending_request and pending_request["to_username"] == from_username:
            manager.remove_pending_request(to_username)
            if accepted:
                chatroom = manager.create_chatroom(to_user, from_user)
                logger.info(
                    f"Chatroom '{chatroom['id']}' created between '{from_username}' "
                    f"and '{to_username}'"
                )
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
                logger.info(
                    f"Chat request from '{to_username}' was declined by "
                    f"'{from_username}'"
                )
                emit(
                    "chat_response",
                    {"accepted": False, "message": "Chat request declined"},
                    room=to_username
                )
        else:
            logger.error(f"No pending chat request found for '{from_username}'")
            emit(
                "chat_response",
                {"accepted": False, "message": "No pending chat request found"},
                room=from_username
            )

@socketio.on("join_room")
def handle_join_room(data):
    username = data.get("username")
    room_id = data.get("room_id")
    logger.info(f"User '{username}' attempting to join room '{room_id}'")
    if manager.user_authorized_in_room(username, room_id):
        logger.info(f"User '{username}' successfully joined room '{room_id}'")
        join_room(room_id)
        emit("join_room_success", {"message": "Joined room successfully"})
        emit("update_user_list", manager.list_users_in_lobby(), broadcast=True)
    else:
        logger.warning(
            f"Unauthorized attempt by user '{username}' to join room '{room_id}'"
        )
        emit("join_room_failure", {"message": "Unauthorized access"})

@socketio.on("leave_room")
def handle_leave_room(data):
    username = data.get("username")
    room_id = data.get("room_id")
    if manager.user_authorized_in_room(username, room_id):
        logger.info(f"User '{username}' left room '{room_id}'")
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
        logger.info(f"User '{username}' sent a message to room '{room_id}'")
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
        logger.warning(
            f"Unauthorized message send attempt by '{username}' to room '{room_id}'"
        )
        emit("error", {"message": "Unauthorized"})

@socketio.on("share_public_key")
def handle_share_public_key(data):
    room_id = data.get("room_id")
    public_key = data.get("public_key")
    username = data.get("username")
    if not room_id:
        logger.error("Could not share public key due to missing room id")
        return
    if not public_key:
        logger.error("Could not share public key due to missing key")
        return
    logger.info(f"Sharing public key of user '{username}' in room '{room_id}'")
    emit(
        "receive_public_key",
        {"public_key": public_key, "username": username},
        room=room_id,
        include_self=False,
    )

@socketio.on("leave_server")
def handle_leave_server(data):
    username = data.get("username")
    user = manager.get_user(username)
    if user:
        logger.info(f"User '{username}' is leaving the server")
        manager.remove_user(username)
        emit("update_user_list", manager.list_users_in_lobby(), broadcast=True)


if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=os.environ["CONTAINER_PORT"])
