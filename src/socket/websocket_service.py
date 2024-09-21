from flask import Flask, render_template
from flask_socketio import SocketIO, join_room, leave_room, send

app = Flask(__name__)
socketio = SocketIO(app)

@socketio.on("join")
def handle_join(data):
    room = data["room"]
    join_room(room)
    send(f"{data["username"]} has joined the room.", to=room)

@socketio.on("message")
def handle_message(data):
    room = data["room"]
    send(data["message"], to=room)

if __name__ == "__main__":
    socketio.run(app, port=5003)
