import os

import socket
from flask import Flask
from flask_socketio import SocketIO

import chat_manager
from chat_manager import RedisChatManager
from kombu_manager import CustomKombuManager

_EXCHANGE_NAME = "chatapp_fanout_exchange"
_QUEUE_NAME_TEMPLATE = "chatapp_queue_{pod_name}"


def init_app():
    app = Flask(__name__)
    app.config["ENV"] = os.environ["FLASK_ENV"]
    app.config["DEBUG"] = os.environ["FLASK_DEBUG"]
    app.config["SECRET_KEY"] = os.environ["FLASK_SECRET_KEY"]
    return app


def _get_rabbit_queue_uri(username, password, host, port, vhost="/"):
    # https://docs.celeryq.dev/projects/kombu/en/latest/userguide/connections.html#urls
    return f"amqp://{username}:{password}@{host}:{port}/{vhost}"


def _get_client_manager(rabbit_queue_uri, pod_name, quorum_size):
    queue_options = {
        "durable": True,
        "queue_arguments": {
            "x-queue-type": "quorum",
            "x-quorum-initial-group-size": int(quorum_size)
        }
    }
    exchange_options = {
        "type": "fanout",
        "durable": True
    }
    client_manager = CustomKombuManager(
        url=rabbit_queue_uri,
        queue_name=_QUEUE_NAME_TEMPLATE.format(pod_name=pod_name),
        channel=_EXCHANGE_NAME,
        queue_options=queue_options,
        exchange_options=exchange_options,
    )
    return client_manager


def init_socket(app):
    alb_dns = os.environ["ALB_DNS"]
    quorum_size = os.environ["RABBIT_QUORUM_SIZE"]
    rabbit_queue_uri = _get_rabbit_queue_uri(
        username=os.environ["RABBIT_USERNAME"],
        password=os.environ["RABBIT_PASSWORD"],
        host=os.environ["RABBIT_NLB_DNS"],
        port=os.environ["RABBIT_PORT"]
    )
    pod_name = socket.gethostname()
    client_manager = _get_client_manager(rabbit_queue_uri, pod_name, quorum_size)
    socketio = SocketIO(
        app,
        client_manager=client_manager,
        cors_allowed_origins=[f"https://{alb_dns}"],
        logger=True,
        engineio_logger=True
    )
    return socketio


def init_chat_manager():
    startup_nodes = chat_manager.get_startup_nodes(
        num_replicas=int(os.environ["NUM_REDIS_REPLICAS_TOTAL"]),
        pod_name_prefix=os.environ["REDIS_POD_NAME_PREFIX"],
        service_name=os.environ["REDIS_SERVICE_NAME"],
        namespace=os.environ["REDIS_NAMESPACE"],
        port=os.environ["REDIS_PORT"]
    )
    manager = RedisChatManager(
        startup_nodes=startup_nodes,
        password=os.environ["REDIS_PASSWORD"]
    )
    return manager
