from kombu import Exchange, Queue
from socketio import KombuManager


class CustomKombuManager(KombuManager):
    def __init__(self, url, queue_name, **kwargs):
        self.queue_name = queue_name
        super().__init__(url, **kwargs)

    def _exchange(self):
        options = {"type": "fanout", "durable": True}
        options.update(self.exchange_options)
        return Exchange(self.channel, **options)

    def _queue(self):
        options = {"durable": True}
        options.update(self.queue_options)
        return Queue(self.queue_name, self._exchange(), **options)
