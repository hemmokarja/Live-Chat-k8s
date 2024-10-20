import os

from flask import Flask
from flask_socketio import SocketIO

import chat_manager
from chat_manager import RedisChatManager


def init_app():
    app = Flask(__name__)
    app.config["ENV"] = os.environ["FLASK_ENV"]
    app.config["DEBUG"] = os.environ["FLASK_DEBUG"]
    app.config["SECRET_KEY"] = os.environ["FLASK_SECRET_KEY"]
    return app


def init_socket(app):
    alb_dns = os.environ["ALB_DNS"]
    redis_port = os.environ["REDIS_PORT"]
    redis_messagebroker_service_name = os.environ["REDIS_MESSAGEBROKER_SERVICE_NAME"]
    socketio = SocketIO(
        app,
        cors_allowed_origins=[f"https://{alb_dns}"],
        message_queue=f"redis://{redis_messagebroker_service_name}:{redis_port}/0",
        logger=True,
        engineio_logger=True
    )
    return socketio


def init_chat_manager():
    startup_nodes = chat_manager.get_startup_nodes(
        num_replicas=int(os.environ["NUM_REDIS_REPLICAS_TOTAL"]),
        pod_name_prefix=os.environ["REDIS_USERSTATE_POD_NAME_PREFIX"],
        service_name=os.environ["REDIS_USERSTATE_SERVICE_NAME"],
        namespace=os.environ["REDIS_USERSTATE_NAMESPACE"],
        port=os.environ["REDIS_PORT"]
    )
    manager = RedisChatManager(
        startup_nodes=startup_nodes,
        password=os.environ["REDIS_PASSWORD"]
    )
    return manager
