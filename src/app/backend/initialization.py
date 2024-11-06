import os

from flask import Flask
from flask_socketio import SocketIO
from socketio import KombuManager

import state_manager
from state_manager import RedisChatManager


def init_app():
    app = Flask(__name__)
    app.config["ENV"] = os.environ["FLASK_ENV"]
    app.config["DEBUG"] = os.environ["FLASK_DEBUG"]
    app.config["SECRET_KEY"] = os.environ["FLASK_SECRET_KEY"]
    return app


def _get_rabbit_queue_uri(username, password, host, port, vhost="/"):
    # https://docs.celeryq.dev/projects/kombu/en/latest/userguide/connections.html#urls
    return f"amqp://{username}:{password}@{host}:{port}/{vhost}"


def _get_client_manager(rabbit_queue_uri):
    exchange_options = {
        "type": "fanout",
        "durable": False
    }
    client_manager = KombuManager(
        url=rabbit_queue_uri,
        channel="chatapp-fanout-exchange",
        exchange_options=exchange_options,
    )
    return client_manager


def init_socket(app):
    alb_dns = os.environ["ALB_DNS"]
    rabbit_queue_uri = _get_rabbit_queue_uri(
        username=os.environ["RABBIT_USERNAME"],
        password=os.environ["RABBIT_PASSWORD"],
        host=os.environ["RABBIT_HOST"],
        port=os.environ["RABBIT_PORT"]
    )
    client_manager = _get_client_manager(rabbit_queue_uri)
    socketio = SocketIO(
        app,
        client_manager=client_manager,
        cors_allowed_origins=[f"https://{alb_dns}"],
        logger=True,
        engineio_logger=True
    )
    return socketio


def init_chat_manager():
    startup_nodes = state_manager.get_startup_nodes(
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
