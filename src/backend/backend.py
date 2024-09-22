from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit, join_room, leave_room

app = Flask(__name__)
app.config["SECRET_KEY"] = "your_secret_key"
socketio = SocketIO(
    app, cors_allowed_origins=["http://localhost:5001", "http://127.0.0.1:5001"]
)

connected_users = {}  # {sid: username}
pending_requests = {}  # {from_sid: to_sid}

def _list_users(connected_users):
    return list(connected_users.values())

def _find_sid(connected_users, username_to_find):
    for sid, username in connected_users.items():
        if username == username_to_find:
            return sid
    return None

@app.route("/")
def index():
    return "WebSocket server running!"

# Check username availability
@app.route("/check_username", methods=["POST"])
def check_username():
    data = request.get_json()
    username = data.get("username")
    if username in connected_users.values():
        return jsonify({"available": False}), 200
    return jsonify({"available": True}), 200

# Handle new connections
@socketio.on("connect")
def handle_connect():
    username = request.args.get("username")
    if not username:
        return False  # Reject the connection
    connected_users[request.sid] = username
    emit("update_user_list", _list_users(connected_users), broadcast=True)

# Handle disconnections
@socketio.on("disconnect")
def handle_disconnect():
    sid = request.sid
    if sid in connected_users:
        del connected_users[sid]
    # Remove any pending requests involving this user
    """
    TODO: eli jos joku on kysynyt tätä käyttäjää chattiin, niin vastataan kieltävästi.

    Mut meneekö tää nyt niin, et jos käyttäjä itse siirtyy chat huoneeseen kun on 
    avonainen chat request jollekin toiselle, lähettää itse accepted:False viestin?
    * from sid = käyttäjä itse 
    * to sid = se jota käyttäjä on pyytänyt chattiin
    --> lähetetään sille joka on saanut kutsun chattiin, et ei sittenkään
    --> MIETI ONKS TÄÄ OIKEIN, vai tulisko vain vetää kutsu pois

    """
    pending_to_remove = [
        from_sid for from_sid, to_sid in pending_requests.items()
        if from_sid == sid or to_sid == sid
    ]
    for from_sid in pending_to_remove:
        to_sid = pending_requests[from_sid]
        del pending_requests[from_sid]
        # Notify the other user that the request was canceled
        emit(
            "chat_response",
            {"accepted": False, "message": "User disconnected"},
            room=to_sid
        )
    emit("update_user_list", _list_users(connected_users), broadcast=True)

# Handle chat request
@socketio.on("chat_request")
def handle_chat_request(data):
    from_sid = request.sid
    from_user = connected_users.get(from_sid)
    to_user = data.get("to_user")

    if not from_user or not to_user:
        return

    # Prevent multiple pending requests from the same user
    if from_sid in pending_requests:
        emit(
            "chat_response",
            {"accepted": False, "message": "You already have a pending chat request"},
            room=from_sid
        )
        return

    # Find the recipient's SID
    to_sid = _find_sid(connected_users, to_user)

    if to_sid:
        pending_requests[from_sid] = to_sid
        # TODO tuleeks tässä circular reference, täähän on itsessäänkin jo chat_requestin sisällä?
        emit("chat_request", {"from_user": from_user}, room=to_sid)
    else:
        # Recipient not connected
        emit(
            "chat_response",
            {"accepted": False, "message": "User not available"},
            room=from_sid
        )

# Handle chat response
@socketio.on("chat_response")
def handle_chat_response(data):
    from_sid = request.sid
    to_user = data.get("from_user")  # 'to' here refers to who we're going to respond, i.e., the requesting user
    accepted = data.get("accepted")

    if not to_user:
        return

    # Find the requesting user's SID
    to_sid = _find_sid(connected_users, to_user)

    if to_sid and to_sid in pending_requests and pending_requests[to_sid] == from_sid:
        # Remove pending request
        del pending_requests[to_sid]
        if accepted:
            # Create a unique room identifier
            room = f"room_{to_user}_{connected_users[from_sid]}"
            # Notify both users to join the room
            emit("chat_response", {"accepted": True, "room": room}, room=to_sid)
            emit("chat_response", {"accepted": True, "room": room}, room=from_sid)
        else:
            # Notify the requesting user that the request was declined
            emit(
                "chat_response",
                {"accepted": False, "message": "Chat request declined"},
                room=to_sid
            )
    else:
        # No pending request found
        pass

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5002)
