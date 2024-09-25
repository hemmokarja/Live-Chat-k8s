import uuid


class User:
    def __init__(self, username):
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
        self.connected_users = {}  # {username: User}
        self.pending_requests = {}  # {from_username: ChatRequest}
        self.chatrooms = {}  # {room_id: ChatRoom}

    def add_user(self, username):
        user = User(username)
        self.connected_users[username] = user
        return user

    def remove_user(self, username):
        if username in self.connected_users:
            _ = self.connected_users.pop(username)
            self.cancel_pending_requests(username)

    def get_user(self, username):
        for user in self.connected_users.values():
            if user.username == username:
                return user
        return None

    def add_pending_request(self, from_user, to_user):
        request = ChatRequest(from_user, to_user)
        self.pending_requests[from_user.username] = request
        return request

    def get_pending_request(self, from_username):
        return self.pending_requests.get(from_username)
    
    def remove_pending_request(self, from_username):
        if from_username in self.pending_requests:
            del self.pending_requests[from_username]

    def cancel_pending_requests(self, from_username):
        to_remove = []
        for from_username, request in self.pending_requests.items():
            if request.from_user == from_username or request.to_user == from_username:
                to_remove.append(from_username)
        for from_username in to_remove:
            self.remove_pending_request(from_username)

    def create_room(self, user1, user2):
        chatroom = ChatRoom(user1, user2)
        self.chatrooms[chatroom.id] = chatroom
        user1.in_room = True
        user2.in_room = True
        return chatroom
    
    def list_users_in_lobby(self):
        return [
            user.username for user in self.connected_users.values() if not user.in_room
        ]

    def user_is_connected(self, username):
        return username in self.connected_users


def user_authorized_in_room(username, room_id, chat_server):
    user = chat_server.get_user(username)
    chatroom = chat_server.chatrooms.get(room_id)
    if user and chatroom and chatroom.is_user_authorized(username):
        return True
    return False
