import json
import logging
import uuid
import hashlib

from redis.cluster import ClusterNode, RedisCluster

logger = logging.getLogger(__name__)


class RedisChatManager:
    def __init__(self, startup_nodes, password, num_partitions=100):
        self.redis = RedisCluster(
            startup_nodes=startup_nodes,
            password=password,
            decode_responses=True
        )
        self.num_partitions = num_partitions

    def _get_partition(self, key):
        """
        Convert the input key (username, room_id, etc.) to a numerical representation
        and take a modulo of the number of partitions. This function can be reused for
        both users and chatrooms.
        """
        key_hash = int(hashlib.md5(key.encode()).hexdigest(), 16)
        return key_hash % self.num_partitions

    # ==================== Connected Users ====================

    def add_user(self, username):
        partition = self._get_partition(username)
        user_data = {
            "username": username,
            "in_room": False
        }
        self.redis.hset(
            f"connected_users{{users_partition_{partition}}}",
            username,
            _to_json(user_data)
        )
        self.redis.sadd(f"users_in_lobby{{lobby_partition_{partition}}}", username)

    def remove_user(self, username):
        partition = self._get_partition(username)
        self.redis.hdel(f"connected_users{{users_partition_{partition}}}", username)
        self.redis.srem(f"users_in_lobby{{lobby_partition_{partition}}}", username)
        self.remove_all_pending_requests(username)

    def get_user(self, username):
        partition = self._get_partition(username)
        user_data = self.redis.hget(
            f"connected_users{{users_partition_{partition}}}", username
        )
        return _from_json(user_data) if user_data else None

    def list_users_in_lobby(self):
        all_users = []
        for partition in range(self.num_partitions):
            users_in_partition = self.redis.smembers(
                f"users_in_lobby{{lobby_partition_{partition}}}"
            )
            all_users.extend(users_in_partition)
        return all_users

    # ==================== Chatrooms ====================

    def create_chatroom(self, user1, user2):
        room_id = str(uuid.uuid4())
        chatroom = {
            "id": room_id,
            "users": [user1["username"], user2["username"]]
        }
        user1["in_room"] = True
        user2["in_room"] = True

        user_partition1 = self._get_partition(user1["username"])
        user_partition2 = self._get_partition(user2["username"])
        room_partition = self._get_partition(room_id)

        pipeline = self.redis.pipeline()
        pipeline.hset(
            f"chatrooms{{room_partition_{room_partition}}}", room_id, _to_json(chatroom)
        )
        pipeline.srem(
            f"users_in_lobby{{lobby_partition_{user_partition1}}}", user1["username"]
        )
        pipeline.srem(
            f"users_in_lobby{{lobby_partition_{user_partition2}}}", user2["username"]
        )
        pipeline.hset(
            f"connected_users{{users_partition_{user_partition1}}}",
            user1["username"],
            _to_json(user1)
        )
        pipeline.hset(
            f"connected_users{{users_partition_{user_partition2}}}",
            user2["username"],
            _to_json(user2)
        )
        pipeline.execute()

        return chatroom
    
    def get_chatroom(self, room_id):
        partition = self._get_partition(room_id)
        room_data = self.redis.hget(f"chatrooms{{room_partition_{partition}}}", room_id)
        return _from_json(room_data) if room_data else None
    
    def leave_chatroom(self, username, room_id):
        user = self.get_user(username)
        chatroom = self.get_chatroom(room_id)

        user_partition = self._get_partition(username)
        room_partition = self._get_partition(room_id)

        user["in_room"] = False

        pipeline = self.redis.pipeline()
        pipeline.sadd(f"users_in_lobby{{lobby_partition_{user_partition}}}", username)
        pipeline.hset(
            f"connected_users{{users_partition_{user_partition}}}",
            username,
            _to_json(user)
        )

        chatroom["users"].remove(username)
        if not chatroom["users"]:
            pipeline.hdel(f"chatrooms{{room_partition_{room_partition}}}", room_id)
        else:
            pipeline.hset(
                f"chatrooms{{room_partition_{room_partition}}}",
                room_id,
                _to_json(chatroom)
            )

        pipeline.execute()

    # ==================== Pending Requests ====================

    def add_pending_request(self, from_username, to_username):
        partition = self._get_partition(from_username)
        request_data = {
            "from_username": from_username,
            "to_username": to_username
        }
        self.redis.hset(
            f"pending_requests{{requests_partition_{partition}}}",
            from_username,
            _to_json(request_data)
        )

    def get_pending_request(self, from_username):
        partition = self._get_partition(from_username)
        request_data = self.redis.hget(
            f"pending_requests{{requests_partition_{partition}}}", from_username
        )
        return _from_json(request_data) if request_data else None

    def remove_pending_request(self, from_username):
        partition = self._get_partition(from_username)
        self.redis.hdel(
            f"pending_requests{{requests_partition_{partition}}}", from_username
        )

    def remove_all_pending_requests(self, username):
        """
        Remove all pending requests for a user, including requests made by or to them.
        To achieve this, we need to search across all partitions and find any requests where
        the user is either the 'from_username' or the 'to_username'.
        """
        for partition in range(self.num_partitions):
            key = f"pending_requests{{requests_partition_{partition}}}"
            pending_requests = self.redis.hgetall(key)
            for from_username, request_data in pending_requests.items():
                request = _from_json(request_data)
                if (
                    request["from_username"] == username 
                    or request["to_username"] == username
                ):
                    self.redis.hdel(key, from_username)

    # ==================== Authorization ====================

    def user_authorized_in_room(self, username, room_id):
        user = self.get_user(username)
        chatroom = self.get_chatroom(room_id)
        if not user:
            logger.warning(
                f"Unauthorized access for user '{username}' to room '{room_id}' due to "
                "user not found"
            )
            return False
        if not chatroom:
            logger.warning(
                f"Unauthorized access for user '{username}' to room '{room_id}' due to "
                "chatroom not found"
            )
            return False
        if username not in chatroom["users"]:
            logger.warning(
                f"Unauthorized access for user '{username}' to room '{room_id}' due to "
                "user not found in chatroom members: {chatroom['users']}"
            )
            return False
        return True


def _to_json(data):
    try:
        return json.dumps(data)
    except (TypeError, ValueError) as e:
        raise ValueError(f"Failed to serialize data: {repr(e)}")


def _from_json(data):
    try:
        return json.loads(data)
    except (TypeError, ValueError) as e:
        raise ValueError(f"Failed to deserialize data: {repr(e)}")


def get_startup_nodes(num_replicas, pod_name_prefix, service_name, namespace, port):
    startup_nodes = []
    for i in range(num_replicas):
        host = f"{pod_name_prefix}-{i}.{service_name}.{namespace}.svc.cluster.local"
        startup_nodes.append(ClusterNode(host=host, port=port))
    return startup_nodes