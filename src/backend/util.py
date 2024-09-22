import uuid


class User:
    def __init__(self, sid, username):
        self.sid = sid
        self.username = username
        self.in_room = False


class ChatRequest:
    def __init__(self, from_user, to_user):
        self.from_user = from_user
        self.to_user = to_user


class ChatRoom:
    def __init__(self, user1, user2):
        self.id = str(uuid.uuid4())
        self.users = [user1, user2]

    def is_user_authorized(self, username):
        return username in [u.username for u in self.users]


class ChatServer:
    def __init__(self):
        self.connected_users = {}  # {sid: User}
        self.pending_requests = {}  # {from_sid: ChatRequest}
        self.chatrooms = {}  # {room_id: ChatRoom}

    def add_user(self, sid, username):
        user = User(sid, username)
        self.connected_users[sid] = user
        return user

    def remove_user(self, sid):
        if sid in self.connected_users:
            user = self.connected_users.pop(sid)
            # Remove any pending requests involving this user
            self.cancel_pending_requests(user)
            return user

    def get_user_by_username(self, username):
        for user in self.connected_users.values():
            if user.username == username:
                return user
        return None

    def get_user_by_sid(self, sid):
        return self.connected_users.get(sid)

    def add_pending_request(self, from_user, to_user):
        request = ChatRequest(from_user, to_user)
        self.pending_requests[from_user.sid] = request
        return request

    def get_pending_request(self, from_sid):
        return self.pending_requests.get(from_sid)
    
    def remove_pending_request(self, from_sid):
        if from_sid in self.pending_requests:
            del self.pending_requests[from_sid]

    def cancel_pending_requests(self, user):
        to_remove = []
        for from_sid, request in self.pending_requests.items():
            if request.from_user == user or request.to_user == user:
                to_remove.append(from_sid)
        for from_sid in to_remove:
            self.remove_pending_request(from_sid)

    def create_room(self, user1, user2):
        chatroom = ChatRoom(user1, user2)
        self.chatrooms[chatroom.id] = chatroom
        user1.in_room = True
        user2.in_room = True
        return chatroom
    
    def list_usernames(self):
        return [
            user.username for user in self.connected_users.values() if not user.in_room
        ]
    
    def user_is_connected(self, sid):
        return sid in self.connected_users
