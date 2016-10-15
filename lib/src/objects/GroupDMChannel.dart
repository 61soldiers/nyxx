part of discord;

/// A group DM channel.
class GroupDMChannel extends Channel {
  Timer _typing;

  /// The ID for the last message in the channel.
  String lastMessageID;

  /// A collection of messages sent to this channel.
  LinkedHashMap<String, Message> messages;

  /// The recipients.
  Map<String, User> recipients;

  GroupDMChannel._new(Client client, Map<String, dynamic> data)
      : super._new(client, data, "private") {
    this.lastMessageID = data['last_message_id'];
    this.messages = new Map<String, Message>();

    this.recipients = new Map<String, User>();
    data['recipients'].forEach((Map<String, dynamic> o) {
      final User user = new User._new(client, o);
      this.recipients[user.id] = user;
    });
  }

  void _cacheMessage(Message message) {
    if (this.messages.length >= this._client._options.messageCacheSize) {
      this.messages.remove(this.messages.values.toList().first.id);
    }
    this.messages[message.id] = message;
  }

  /// Sends a message.
  ///
  /// Throws an [Exception] if the HTTP request errored.
  ///     Channel.sendMessage("My content!");
  Future<Message> sendMessage(String content, [MessageOptions options]) async {
    MessageOptions newOptions;
    if (options == null) {
      newOptions = new MessageOptions();
    } else {
      newOptions = options;
    }

    String newContent;
    if (newOptions.disableEveryone == true ||
        (newOptions.disableEveryone == null &&
            this._client._options.disableEveryone)) {
      newContent = content
          .replaceAll("@everyone", "@\u200Beveryone")
          .replaceAll("@here", "@\u200Bhere");
    } else {
      newContent = content;
    }

    final _HttpResponse r = await this._client._http.post(
        '/channels/${this.id}/messages', <String, dynamic>{
      "content": newContent,
      "tts": newOptions.tts,
      "nonce": newOptions.nonce
    });
    return new Message._new(this._client, r.json as Map<String, dynamic>);
  }

  /// Gets a [Message] object. Only usable by bot accounts.
  ///
  /// Throws an [Exception] if the HTTP request errored or if the client user
  /// is not a bot.
  ///     Channel.getMessage("message id");
  Future<Message> getMessage(dynamic message) async {
    if (this._client.user.bot) {
      final String id = this._client._util.resolve('message', message);

      final _HttpResponse r =
          await this._client._http.get('/channels/${this.id}/messages/$id');
      return new Message._new(this._client, r.json as Map<String, dynamic>);
    } else {
      throw new Exception("'getMessage' is only usable by bot accounts.");
    }
  }

  /// Starts typing.
  Future<Null> startTyping() async {
    await this._client._http.post("/channels/$id/typing", {});
    return null;
  }

  /// Loops `startTyping` until `stopTypingLoop` is called.
  void startTypingLoop() {
    startTyping();
    this._typing = new Timer.periodic(
        const Duration(seconds: 7), (Timer t) => startTyping());
  }

  /// Stops a typing loop if one is running.
  void stopTypingLoop() {
    this._typing?.cancel();
  }
}
