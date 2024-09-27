import redis
import uuid
import json
import logging

logger = logging.getLogger(__name__)


def to_json(data):
    try:
        return json.dumps(data)
    except (TypeError, ValueError) as e:
        raise ValueError(f"Failed to serialize data: {repr(e)}")


def from_json(data):
    try:
        return json.loads(data)
    except (TypeError, ValueError) as e:
        raise ValueError(f"Failed to deserialize data: {repr(e)}")


class RedisChatManager:
    def __init__(self, host="localhost", port=6379, db=0):
        self.redis = redis.StrictRedis(host=host, port=port, db=db)

    def add_user(self, username):
        user_data = {
            "username": username,
            "in_room": False
        }
        self.redis.hset("connected_users", username, to_json(user_data))
        self.redis.sadd("users_in_lobby", username)

    def remove_user(self, username):
        self.redis.hdel("connected_users", username)
        self.redis.srem("users_in_lobby", username)
        self.remove_all_pending_requests(username)

    def get_user(self, username):
        user_data = self.redis.hget("connected_users", username)
        return from_json(user_data) if user_data else None

    def list_users_in_lobby(self):
        return [u.decode("UTF-8") for u in self.redis.smembers("users_in_lobby")]

    def create_chatroom(self, user1, user2):
        room_id = str(uuid.uuid4())
        chatroom = {
            "id": room_id,
            "users": [user1["username"], user2["username"]]
        }
        user1["in_room"] = True
        user2["in_room"] = True
        pipeline = self.redis.pipeline()
        pipeline.hset("chatrooms", room_id, to_json(chatroom))
        pipeline.srem("users_in_lobby", user1["username"])
        pipeline.srem("users_in_lobby", user2["username"])
        pipeline.hset("connected_users", user1["username"], to_json(user1))
        pipeline.hset("connected_users", user2["username"], to_json(user2))
        pipeline.execute()
        return chatroom
    
    def get_chatroom(self, room_id):
        room_data = self.redis.hget("chatrooms", room_id)
        if room_data:
            return from_json(room_data)
        return None
    
    def leave_chatroom(self, username, room_id):
        user = self.get_user(username)
        chatroom = self.get_chatroom(room_id)

        user["in_room"] = False
        
        pipeline = self.redis.pipeline()
        pipeline.sadd("users_in_lobby", username)
        pipeline.hset("connected_users", username, to_json(user))
        
        chatroom["users"].remove(username)
        if not chatroom["users"]:
            pipeline.hdel("chatrooms", room_id)
        else:
            pipeline.hset("chatrooms", room_id, to_json(chatroom))

        pipeline.execute()

    def add_pending_request(self, from_username, to_username):
        request_data = {
            "from_username": from_username,
            "to_username": to_username
        }
        self.redis.hset("pending_requests", from_username, to_json(request_data))

    def get_pending_request(self, from_username):
        request_data = self.redis.hget("pending_requests", from_username)
        return from_json(request_data) if request_data else None

    def remove_pending_request(self, from_username):
        self.redis.hdel("pending_requests", from_username)

    def remove_all_pending_requests(self, username):
        pending_requests = self.redis.hgetall("pending_requests")
        for from_username, request_data in pending_requests.items():
            request = from_json(request_data)
            if (
                request["from_username"] == username
                or request["to_username"] == username
            ):
                self.redis.hdel("pending_requests", from_username)

    def user_authorized_in_room(self, username, room_id):
        user = self.get_user(username)
        chatroom = self.get_chatroom(room_id)
        if not user:
            logger.warning(
                f"Unauthorized access for user '{username}' to room '{room_id}' due to "
                "user not found"
            )
            return False
        if not user:
            logger.warning(
                f"Unauthorized access for user '{username}' to room '{room_id}' due to "
                "chatroom not found"
            )
            return False
        if not username in chatroom["users"]:
            logger.warning(
                f"Unauthorized access for user '{username}' to room '{room_id}' due to "
                f"user not found in chatroom members: {chatroom['users']}"
            )
        return True
